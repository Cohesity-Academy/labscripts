#$Source = "https://github.com/Cohesity-Academy/labscripts/raw/refs/heads/main/theupgrader.ps1"; $Destination = "theupgrader.ps1"; Invoke-WebRequest -Uri $source -OutFile $Destination; ./theupgrader.ps1

Install-Script -Name winget-install -Force
winget-install
start-sleep 10
$wgetpath = dir "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe"
TAKEOWN /F $wgetpath.fullname /R /A /D Y
ICACLS $wgetpath.fullname /grant Administrators:F /T
winget upgrade winscp --silent --accept-package-agreements --accept-source-agreements
winget upgrade putty --silent --accept-package-agreements
winget upgrade wireshark --silent --accept-package-agreements
winget upgrade firefox --silent --accept-package-agreements
# winget upgrade chrome --silent --accept-package-agreements
# winget upgrade "Microsoft SQL Server Management Studio" --silent --accept-package-agreements
