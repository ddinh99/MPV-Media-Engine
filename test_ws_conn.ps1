$ws = New-Object System.Net.WebSockets.ClientWebSocket
$ct = [System.Threading.CancellationToken]::None
$uri = New-Object System.Uri("ws://127.0.0.1:9002/")
Write-Host "Connecting to $uri..."
$ws.ConnectAsync($uri, $ct).Wait()
Write-Host "Connected!"
$msg = '{"command": ["set_property", "mute", true]}'
$bytes = [System.Text.Encoding]::UTF8.GetBytes($msg)
$segment = New-Object System.ArraySegment[byte] -ArgumentList @(,$bytes)
$ws.SendAsync($segment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $ct).Wait()
Write-Host "Sent!"
$ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "", $ct).Wait()
Write-Host "Closed!"
