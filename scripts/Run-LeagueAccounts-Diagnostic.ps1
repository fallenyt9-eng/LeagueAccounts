# Run from the folder containing LeagueAccounts-Diagnostic.exe.
# Writes a shareable log directory on the user's Desktop.
# No account passwords or application storage are read.
$ErrorActionPreference = "Continue"
$exe = Join-Path $PSScriptRoot "LeagueAccounts-Diagnostic.exe"
$desktop = [Environment]::GetFolderPath("Desktop")
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$out = Join-Path $desktop "LeagueAccounts-Diagnostic-$stamp"
New-Item -ItemType Directory -Force -Path $out | Out-Null
$summary = Join-Path $out "summary.txt"
function Note([string]$message) { $message | Tee-Object -FilePath $summary -Append }
Note "Diagnostic runner started: $(Get-Date -Format o)"
Note "System: $([Environment]::OSVersion.VersionString)"
Note "Executable exists: $(Test-Path -LiteralPath $exe)"
Note "64-bit OS: $([Environment]::Is64BitOperatingSystem)"
$webview = @(
  "HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F1E7A4B1-2D9C-4A5A-B259-1A4D81E30224}",
  "HKCU:\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F1E7A4B1-2D9C-4A5A-B259-1A4D81E30224}",
  "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F1E7A4B1-2D9C-4A5A-B259-1A4D81E30224}"
)
foreach ($path in $webview) {
  $version = (Get-ItemProperty -LiteralPath $path -Name pv -ErrorAction SilentlyContinue).pv
  if ($version) { Note "WebView2 runtime registered: $version" }
}
$start = Get-Date
if (Test-Path -LiteralPath $exe) {
  try {
    $process = Start-Process -FilePath $exe -ArgumentList "--diagnostics" -PassThru -ErrorAction Stop
    Note "Launch reported PID: $($process.Id)"
    try {
      Wait-Process -Id $process.Id -Timeout 20 -ErrorAction Stop
      $process.Refresh()
      Note "Exited during 20s observation; exit code: $($process.ExitCode)"
    } catch {
      Note "Process did not exit within 20s (or cannot be queried). Check whether a window opened."
    }
  } catch {
    Note "Process creation failed. Exception type: $($_.Exception.GetType().Name)"
    Note "Native error HRESULT: $($_.Exception.HResult)"
  }
}
Note "Observation started: $($start.ToString('o'))"
$diagnostic = Join-Path $env:TEMP "LeagueAccounts-Diagnostics"
if (Test-Path -LiteralPath $diagnostic) {
  Get-ChildItem -LiteralPath $diagnostic -Filter 'startup-*.log' -File |
    Where-Object { $_.LastWriteTime -ge $start.AddMinutes(-1) } |
    Copy-Item -Destination $out -ErrorAction SilentlyContinue
}
$logs = Join-Path $env:APPDATA "LeagueAccounts\logs"
if (Test-Path -LiteralPath $logs) {
  Get-ChildItem -LiteralPath $logs -Filter 'leagueaccounts-*.log' -File |
    Sort-Object LastWriteTime -Descending | Select-Object -First 3 |
    Copy-Item -Destination $out -ErrorAction SilentlyContinue
}
$events = @()
foreach ($name in @("Application","System")) {
  try {
    $events += Get-WinEvent -FilterHashtable @{LogName=$name; StartTime=$start.AddMinutes(-2); Level=1,2,3} -ErrorAction Stop |
      Where-Object { $_.ProviderName -match 'Application Error|Windows Error Reporting|Application Hang|SideBySide|AppModel|Service Control Manager|DistributedCOM' -or $_.Message -match 'LeagueAccounts|WebView2|msedgewebview2|0x800700' } |
      Select-Object TimeCreated,LogName,ProviderName,Id,LevelDisplayName,Message
  } catch {
    Note "No matching $name events or log unavailable."
  }
}
$events | Format-List | Out-File (Join-Path $out "windows-events.txt") -Width 240 -Encoding utf8
Note "Saved report in: $out"
Write-Host "Share the folder $out after reviewing for private paths or information." -ForegroundColor Green
Read-Host "Press Enter to close"
