# C:\Users\Dai\Desktop\OriginalArkanoid\mpv_websocket_bridge.ps1

$pipeName = 'mpvsocket'
$wsPort = 9002

Write-Host '=================================================='
Write-Host ' MVP Sound Engine - PowerShell WebSocket Bridge'
Write-Host '=================================================='

# 1. Connect to MPV (Try Named Pipe first, fallback to TCP Port 9001)
$connected = $false
$writer = $null
$pipe = $null
$tcpClient = $null

Write-Host 'Attempting to connect to MPV Named Pipe (\\.\pipe\mpvsocket)...'
try {
    $pipe = New-Object System.IO.Pipes.NamedPipeClientStream('.', $pipeName, [System.IO.Pipes.PipeDirection]::InOut)
    $pipe.Connect(1000)
    $writer = New-Object System.IO.StreamWriter($pipe)
    $writer.AutoFlush = $true
    Write-Host '✓ Connected to MPV via Named Pipe successfully!'
    $connected = $true
} catch {
    Write-Host '  Named Pipe connection failed. Trying TCP (127.0.0.1:9001)...'
}

if (-not $connected) {
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.Connect('127.0.0.1', 9001)
        $stream = $tcpClient.GetStream()
        $writer = New-Object System.IO.StreamWriter($stream)
        $writer.AutoFlush = $true
        Write-Host '✓ Connected to MPV via TCP (127.0.0.1:9001) successfully!'
        $connected = $true
    } catch {
        Write-Host '✗ Could not connect to MPV via Named Pipe or TCP.'
        Write-Host 'Please start MPV first with either:'
        Write-Host '  mpv --input-ipc-server=\\.\pipe\mpvsocket'
        Write-Host '  mpv --input-ipc-server=tcp://127.0.0.1:9001'
        exit
    }
}

# 2. Start WebSocket Listener
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add('http://localhost:9002/')
$listener.Prefixes.Add('http://127.0.0.1:9002/')

try {
    $listener.Start()
    Write-Host '✓ WebSocket bridge listening on ws://127.0.0.1:9002/'
    Write-Host 'Press Ctrl+C in this window to stop the bridge.'
} catch {
    Write-Host '✗ Could not start WebSocket listener.'
    $writer.Close()
    $pipe.Close()
    exit
}

try {
    while ($listener.IsListening) {
        try {
            $context = $listener.GetContext()
            if ($context.Request.IsWebSocketRequest) {
                Write-Host 'Accepting browser client connection...'
                $wsContext = $context.AcceptWebSocketAsync([System.Management.Automation.Language.NullString]::Value).Result
                $webSocket = $wsContext.WebSocket
                Write-Host '✓ Browser client connected!'

                $buffer = New-Object byte[] 8192
                
                while ($webSocket.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
                    $segment = New-Object System.ArraySegment[byte] -ArgumentList @(,$buffer)
                    $ct = [System.Threading.CancellationToken]::None
                    
                    # Receive message from WebSocket
                    $receiveTask = $webSocket.ReceiveAsync($segment, $ct)
                    $result = $receiveTask.Result

                    if ($result.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) {
                        Write-Host 'Browser client disconnected.'
                        $webSocket.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, [string]::Empty, $ct).Wait()
                        break
                    }
                    
                    if ($result.Count -gt 0) {
                        $msg = [System.Text.Encoding]::UTF8.GetString($buffer, 0, $result.Count)
                        if ($msg.Trim()) {
                            Write-Host "Forwarding: $msg"
                            try {
                                # Write directly to MPV named pipe
                                $writer.WriteLine($msg)
                            } catch {
                                Write-Host "Failed to write to MPV pipe. MPV probably closed."
                                Write-Host "Exiting bridge..."
                                break
                            }
                        }
                    }
                }
            } else {
                $context.Response.StatusCode = 400
                $context.Response.Close()
            }
        } catch {
            Write-Host "Client error: $($_.Exception.Message)"
            Write-Host "Exiting bridge due to fatal client loop error."
            break
        }
    }
} finally {
    $listener.Stop()
    if ($writer) { $writer.Close() }
    if ($pipe) { $pipe.Close() }
    if ($tcpClient) { $tcpClient.Close() }
    Write-Host 'Bridge shut down.'
}
