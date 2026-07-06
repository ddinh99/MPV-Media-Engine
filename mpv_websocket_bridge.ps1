# C:\Users\Dai\Desktop\OriginalArkanoid\mpv_websocket_bridge.ps1

$pipeName = 'mpvsocket'
$wsPort = 9002

Write-Host '=================================================='
Write-Host ' MVP Sound Engine - PowerShell WebSocket Bridge'
Write-Host '=================================================='

# 1. Connect to MPV Named Pipe
Write-Host 'Connecting to MPV Named Pipe: \\.\pipe\mpvsocket...'
try {
    $pipe = New-Object System.IO.Pipes.NamedPipeClientStream('.', $pipeName, [System.IO.Pipes.PipeDirection]::InOut)
    $pipe.Connect(3000)
    $writer = New-Object System.IO.StreamWriter($pipe)
    $writer.AutoFlush = $true
    Write-Host '✓ Connected to MPV successfully!'
} catch {
    Write-Host '✗ Could not connect to MPV.'
    Write-Host 'Please start MPV first with:'
    Write-Host '  mpv --input-ipc-server=\\.\pipe\mpvsocket C:\GTCM.mp4'
    exit
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
                $wsContext = $context.AcceptWebSocketAsync($null).Result
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
                            Write-Host 'Forwarding message to MPV...'
                            # Write directly to MPV named pipe
                            $writer.WriteLine($msg)
                        }
                    }
                }
            } else {
                $context.Response.StatusCode = 400
                $context.Response.Close()
            }
        } catch {
            Write-Host "Client error: $($_.Exception.Message)"
        }
    }
} finally {
    $listener.Stop()
    $writer.Close()
    $pipe.Close()
    Write-Host 'Bridge shut down.'
}
