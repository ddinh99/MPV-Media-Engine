# C:\Users\Dai\Desktop\OriginalArkanoid\test_pipe_ipc.ps1

$pipeName = 'mpvsocket'

Write-Host '=============================================='
Write-Host '  MPV IPC Named Pipe PowerShell Connection Test'
Write-Host '=============================================='

try {
    Write-Host 'Connecting to Named Pipe: \\.\pipe\mpvsocket...'
    
    $pipe = New-Object System.IO.Pipes.NamedPipeClientStream('.', $pipeName, [System.IO.Pipes.PipeDirection]::InOut)
    $pipe.Connect(2000)
    
    Write-Host 'Connected to MPV Named Pipe successfully!'
    
    $writer = New-Object System.IO.StreamWriter($pipe)
    $writer.AutoFlush = $true

    # Test 1: Mute
    Write-Host 'Test 1: Muting audio for 3 seconds...'
    $muteCmd = '{"command": ["set_property", "mute", true]}'
    $writer.WriteLine($muteCmd)

    Start-Sleep -Seconds 3

    # Test 2: Unmute
    Write-Host 'Test 2: Unmuting audio...'
    $unmuteCmd = '{"command": ["set_property", "mute", false]}'
    $writer.WriteLine($unmuteCmd)

    # Test 3: Apply volume filter
    Write-Host 'Test 3: Setting volume filter to -10dB...'
    $filterCmd = '{"command": ["set_property", "af", "lavfi=[volume=volume=-10dB]"]}'
    $writer.WriteLine($filterCmd)

    Start-Sleep -Seconds 3

    # Test 4: Clear filters
    Write-Host 'Test 4: Clearing filters...'
    $clearCmd = '{"command": ["set_property", "af", ""]}'
    $writer.WriteLine($clearCmd)

    Write-Host 'Closing connection...'
    $writer.Close()
    $pipe.Close()
    Write-Host 'Test completed successfully!'

} catch {
    Write-Host 'Error connecting to Named Pipe.'
    Write-Host 'Make sure MPV is running with:'
    Write-Host 'mpv --input-ipc-server=\\.\pipe\mpvsocket C:\GTCM.mp4'
}
