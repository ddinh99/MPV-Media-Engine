# C:\Users\Dai\Desktop\OriginalArkanoid\test_ipc.ps1

$port = 9001
$ip = "127.0.0.1"

Write-Host "=============================================="
Write-Host "  MPV IPC Simple PowerShell Connection Test"
Write-Host "=============================================="

try {
    Write-Host "Connecting to MPV on $ip:$port..."
    $client = New-Object System.Net.Sockets.TcpClient($ip, $port)
    Write-Host "✓ Connected to MPV successfully!" -ForegroundColor Green
    
    $stream = $client.GetStream()
    $writer = New-Object System.IO.StreamWriter($stream)
    $writer.AutoFlush = $true

    # Helper function to send commands
    function Send-MpvCommand($commandObj) {
        $jsonStr = (ConvertTo-Json $commandObj -Compress)
        Write-Host "Sending: $jsonStr"
        $writer.WriteLine($jsonStr)
    }

    # Test 1: Mute
    Write-Host "`n--- Test 1: Muting audio for 3 seconds ---"
    $muteCmd = @{
        command = @("set_property", "mute", $true)
    }
    Send-MpvCommand $muteCmd

    Start-Sleep -Seconds 3

    # Test 2: Unmute
    Write-Host "`n--- Test 2: Unmuting audio ---"
    $unmuteCmd = @{
        command = @("set_property", "mute", $false)
    }
    Send-MpvCommand $unmuteCmd

    # Test 3: Apply volume filter
    Write-Host "`n--- Test 3: Setting volume filter to -10dB ---"
    $filterCmd = @{
        command = @("set_property", "af", "lavfi=[volume=volume=-10dB]")
    }
    Send-MpvCommand $filterCmd

    Start-Sleep -Seconds 3

    # Test 4: Clear filters
    Write-Host "`n--- Test 4: Clearing filters ---"
    $clearCmd = @{
        command = @("set_property", "af", "")
    }
    Send-MpvCommand $clearCmd

    Write-Host "`nClosing connection..."
    $writer.Close()
    $client.Close()
    Write-Host "Test completed!" -ForegroundColor Green

} catch {
    Write-Host "`n✗ Error connecting to MPV: $_" -ForegroundColor Red
    Write-Host "Make sure MPV is running with this command:"
    Write-Host "  mpv --input-ipc-server=tcp://127.0.0.1:9001 `"C:\path\to\movie.mp4`""
}
