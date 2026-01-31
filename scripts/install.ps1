# set color theme
$Theme = @{
    Primary   = 'Cyan'
    Success   = 'Green'
    Warning   = 'Yellow'
    Error     = 'Red'
    Info      = 'White'
}

# ASCII Logo
$Logo = @"
   ██████╗██╗   ██╗██████╗ ███████╗ ██████╗ ██████╗      ██████╗ ██████╗  ██████╗   
  ██╔════╝██║   ██║██╔══██╗██╔════╝██╔═══██╗██╔══██╗     ██╔══██╗██╔══██╗██╔═══██╗  
  ██║     ██║   ██║██████╔╝███████╗██║   ██║██████╔╝     ██████╔╝██████╔╝██║   ██║  
  ██║     ██║   ██║██╔══██╗╚════██║██║   ██║██╔══██╗     ██╔═══╝ ██╔══██╗██║   ██║  
  ╚██████╗╚██████╔╝██║  ██║███████║╚██████╔╝██║  ██║     ██║     ██║  ██║╚██████╔╝  
   ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝     ╚═╝     ╚═╝  ╚═╝ ╚═════╝  
"@

# Beautiful Output Function
function Write-Styled {
    param (
        [string]$Message,
        [string]$Color = $Theme.Info,
        [string]$Prefix = "",
        [switch]$NoNewline
    )
    $symbol = switch ($Color) {
        $Theme.Success { "[OK]" }
        $Theme.Error   { "[X]" }
        $Theme.Warning { "[!]" }
        default        { "[*]" }
    }
    
    $output = if ($Prefix) { "$symbol $Prefix :: $Message" } else { "$symbol $Message" }
    if ($NoNewline) {
        Write-Host $output -ForegroundColor $Color -NoNewline
    } else {
        Write-Host $output -ForegroundColor $Color
    }
}

# Show Logo
Write-Host $Logo -ForegroundColor $Theme.Primary

# ====== CONFIG ======
$version = "1.0.0"
$downloadUrl = "https://example.com/CursorFreeVIP_1.0.0_windows.exe"
# ====================

Write-Host "Version $version" -ForegroundColor $Theme.Info
Write-Host "Created by YeongPin`n" -ForegroundColor $Theme.Info

# Set TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Main installation function
function Install-CursorFreeVIP {
    Write-Styled "Start downloading Cursor Free VIP" -Color $Theme.Primary -Prefix "Download"
    
    try {
        $DownloadsPath = [Environment]::GetFolderPath("UserProfile") + "\Downloads"
        $downloadPath = Join-Path $DownloadsPath "CursorFreeVIP_${version}_windows.exe"
        
        # Check if file already exists
        if (Test-Path $downloadPath) {
            Write-Styled "Found existing installation file" -Color $Theme.Success -Prefix "Found"
            Write-Styled "Location: $downloadPath" -Color $Theme.Info -Prefix "Location"
            
            # Check admin rights
            $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
            ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            
            if (-not $isAdmin) {
                Write-Styled "Requesting administrator privileges..." -Color $Theme.Warning -Prefix "Admin"
                
                $startInfo = New-Object System.Diagnostics.ProcessStartInfo
                $startInfo.FileName = $downloadPath
                $startInfo.UseShellExecute = $true
                $startInfo.Verb = "runas"
                
                try {
                    [System.Diagnostics.Process]::Start($startInfo) | Out-Null
                    Write-Styled "Program started with admin privileges" -Color $Theme.Success -Prefix "Launch"
                    return
                }
                catch {
                    Write-Styled "Failed to start with admin privileges. Starting normally..." -Color $Theme.Warning -Prefix "Warning"
                    Start-Process $downloadPath
                    return
                }
            }
            
            Start-Process $downloadPath
            return
        }
        
        Write-Styled "No existing file found, starting download..." -Color $Theme.Primary -Prefix "Download"
        
        # Create WebClient
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "PowerShell Script")

        # Progress variables
        $Global:downloadedBytes = 0
        $Global:totalBytes = 0
        $Global:lastProgress = 0
        $Global:lastBytes = 0
        $Global:lastTime = Get-Date

        # Progress event
        Register-ObjectEvent -InputObject $webClient -EventName DownloadProgressChanged -Action {
            $Global:downloadedBytes = $EventArgs.BytesReceived
            $Global:totalBytes = $EventArgs.TotalBytesToReceive
            if ($Global:totalBytes -gt 0) {
                $progress = [math]::Round(($Global:downloadedBytes / $Global:totalBytes) * 100, 1)
                
                if ($progress -gt $Global:lastProgress + 1) {
                    $Global:lastProgress = $progress
                    $downloadedMB = [math]::Round($Global:downloadedBytes / 1MB, 2)
                    $totalMB = [math]::Round($Global:totalBytes / 1MB, 2)
                    
                    $currentTime = Get-Date
                    $timeSpan = ($currentTime - $Global:lastTime).TotalSeconds
                    if ($timeSpan -gt 0) {
                        $bytesChange = $Global:downloadedBytes - $Global:lastBytes
                        $speed = $bytesChange / $timeSpan
                        
                        $speedDisplay = if ($speed -gt 1MB) {
                            "$([math]::Round($speed / 1MB, 2)) MB/s"
                        } elseif ($speed -gt 1KB) {
                            "$([math]::Round($speed / 1KB, 2)) KB/s"
                        } else {
                            "$([math]::Round($speed, 2)) B/s"
                        }
                        
                        Write-Host "`rDownloading: $downloadedMB MB / $totalMB MB ($progress%) - $speedDisplay" -NoNewline -ForegroundColor Cyan
                        
                        $Global:lastBytes = $Global:downloadedBytes
                        $Global:lastTime = $currentTime
                    }
                }
            }
        } | Out-Null

        # Download completed event
        Register-ObjectEvent -InputObject $webClient -EventName DownloadFileCompleted -Action {
            Write-Host "`r" -NoNewline
            Write-Styled "Download completed!" -Color $Theme.Success -Prefix "Complete"
        } | Out-Null

        # Start download
        $webClient.DownloadFileAsync([Uri]$downloadUrl, $downloadPath)

        # Wait for download to complete
        while ($webClient.IsBusy) {
            Start-Sleep -Milliseconds 100
        }
        
        Write-Styled "File location: $downloadPath" -Color $Theme.Info -Prefix "Location"
        Write-Styled "Starting program..." -Color $Theme.Primary -Prefix "Launch"
        
        Start-Process $downloadPath
    }
    catch {
        Write-Styled $_.Exception.Message -Color $Theme.Error -Prefix "Error"
        throw
    }
}

# Execute installation
try {
    Install-CursorFreeVIP
}
catch {
    Write-Styled "Download failed" -Color $Theme.Error -Prefix "Error"
    Write-Styled $_.Exception.Message -Color $Theme.Error
}
finally {
    Write-Host "`nPress any key to exit..." -ForegroundColor $Theme.Info
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}
