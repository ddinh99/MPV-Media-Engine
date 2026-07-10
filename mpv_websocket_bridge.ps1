# mpv_websocket_bridge.ps1 — relays app WebSocket <-> mpv named pipe, both directions.

$pipeName = 'mpvsocket'
$wsPort = 9002

# The app spawns this script with stdout drained and discarded, so failures are
# invisible unless they also land in a file. Keep the log tiny and per-pipe.
$logFile = Join-Path $env:TEMP "mpv_bridge_$pipeName.log"
function Log($msg) {
    Write-Host $msg
    try { Add-Content -Path $logFile -Value "[$(Get-Date -Format 'HH:mm:ss')] $msg" } catch {}
}

Log '=================================================='
Log ' MVP Sound Engine - PowerShell WebSocket Bridge'
Log '=================================================='

# 1. Connect to MPV (Try Named Pipe first, fallback to TCP Port 9001)
$connected = $false
$mpvStream = $null
$pipe = $null
$tcpClient = $null

Log "Attempting to connect to MPV Named Pipe (\\.\pipe\$pipeName)..."
try {
    # PipeOptions.Asynchronous is load-bearing: without it the pipe handle is
    # non-overlapped and Windows serializes operations on it, so one pending
    # read (waiting for an mpv reply/event) blocks every write until it
    # completes — which stalls ALL app->mpv commands, not just queries.
    $pipe = New-Object System.IO.Pipes.NamedPipeClientStream('.', $pipeName, [System.IO.Pipes.PipeDirection]::InOut, [System.IO.Pipes.PipeOptions]::Asynchronous)
    $pipe.Connect(5000)
    $mpvStream = $pipe
    Log 'OK Connected to MPV via Named Pipe successfully!'
    $connected = $true
} catch {
    Log '  Named Pipe connection failed. Trying TCP (127.0.0.1:9001)...'
}

if (-not $connected) {
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.Connect('127.0.0.1', 9001)
        $mpvStream = $tcpClient.GetStream()
        Log 'OK Connected to MPV via TCP (127.0.0.1:9001) successfully!'
        $connected = $true
    } catch {
        Log 'FAIL Could not connect to MPV via Named Pipe or TCP.'
        Log 'Please start MPV first with either:'
        Log '  mpv --input-ipc-server=\\.\pipe\mpvsocket'
        Log '  mpv --input-ipc-server=tcp://127.0.0.1:9001'
        exit
    }
}

# Reader and writer share the same duplex stream so app->mpv commands and
# mpv->app replies/events can flow at the same time.
$writer = New-Object System.IO.StreamWriter($mpvStream)
$writer.AutoFlush = $true
$reader = New-Object System.IO.StreamReader($mpvStream)

# One pipe read is kept pending at all times (even between WebSocket clients),
# so mpv's replies are never lost to a torn-down read loop.
$pipeReadTask = $reader.ReadLineAsync()
$mpvClosed = $false

# 2. Start WebSocket Listener
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add('http://localhost:' + $wsPort + '/')
$listener.Prefixes.Add('http://127.0.0.1:' + $wsPort + '/')

try {
    $listener.Start()
    Log ('OK WebSocket bridge listening on ws://127.0.0.1:' + $wsPort + '/')
    Log 'Press Ctrl+C in this window to stop the bridge.'
} catch {
    Log 'FAIL Could not start WebSocket listener.'
    $writer.Close()
    if ($pipe) { $pipe.Close() }
    if ($tcpClient) { $tcpClient.Close() }
    exit
}

try {
    while ($listener.IsListening -and -not $mpvClosed) {
        try {
            $context = $listener.GetContext()
            if ($context.Request.IsWebSocketRequest) {
                Log 'Accepting app client connection...'
                $wsContext = $context.AcceptWebSocketAsync([System.Management.Automation.Language.NullString]::Value).Result
                $webSocket = $wsContext.WebSocket
                Log 'OK App client connected!'

                $buffer = New-Object byte[] 8192
                $ct = [System.Threading.CancellationToken]::None
                $segment = New-Object System.ArraySegment[byte] -ArgumentList @(,$buffer)
                $wsReceiveTask = $webSocket.ReceiveAsync($segment, $ct)

                # Service whichever side has data first: mpv's pipe (replies/
                # events, forwarded to the app) or the WebSocket (commands,
                # forwarded to mpv). WaitAny keeps this single-threaded.
                while ($webSocket.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
                    $completedIndex = [System.Threading.Tasks.Task]::WaitAny(@($pipeReadTask, $wsReceiveTask))

                    if ($completedIndex -eq 0) {
                        # -- MPV -> App --
                        $line = $null
                        try {
                            $line = $pipeReadTask.Result
                        } catch {
                            Log "MPV read error: $($_.Exception.Message)"
                            $mpvClosed = $true
                            break
                        }
                        if ($null -eq $line) {
                            Log 'MPV closed the connection.'
                            $mpvClosed = $true
                            break
                        }
                        if ($line.Trim()) {
                            try {
                                $sendBytes = [System.Text.Encoding]::UTF8.GetBytes($line)
                                $sendSegment = New-Object System.ArraySegment[byte] -ArgumentList @(,$sendBytes)
                                $webSocket.SendAsync($sendSegment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $ct).Wait()
                            } catch {
                                Log "Failed to forward MPV reply to app: $($_.Exception.Message)"
                                break
                            }
                        }
                        $pipeReadTask = $reader.ReadLineAsync()
                    } else {
                        # -- App -> MPV --
                        $result = $null
                        try {
                            $result = $wsReceiveTask.Result
                        } catch {
                            Log "WebSocket receive error: $($_.Exception.Message)"
                            break
                        }

                        if ($result.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) {
                            Log 'App client disconnected.'
                            $webSocket.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, [string]::Empty, $ct).Wait()
                            break
                        }

                        if ($result.Count -gt 0) {
                            $msg = [System.Text.Encoding]::UTF8.GetString($buffer, 0, $result.Count)
                            if ($msg.Trim() -eq "__KILL_BRIDGE__") {
                                Log "Received kill command from app. Exiting bridge gracefully."
                                exit 0
                            }
                            if ($msg.Trim()) {
                                Log "Forwarding: $msg"
                                try {
                                    $writer.WriteLine($msg)
                                } catch {
                                    Log "Failed to write to MPV pipe. MPV probably closed."
                                    $mpvClosed = $true
                                    break
                                }
                            }
                        }
                        $wsReceiveTask = $webSocket.ReceiveAsync($segment, $ct)
                    }
                }
            } else {
                $context.Response.StatusCode = 400
                $context.Response.Close()
            }
        } catch {
            Log "Client error: $($_.Exception.Message)"
            Log "Exiting bridge due to fatal client loop error."
            break
        }
    }
} finally {
    $listener.Stop()
    if ($writer) { try { $writer.Close() } catch {} }
    if ($pipe) { try { $pipe.Close() } catch {} }
    if ($tcpClient) { try { $tcpClient.Close() } catch {} }
    Log 'Bridge shut down.'
}
