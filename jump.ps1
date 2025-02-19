$path = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"
Set-ItemProperty -Path $path -Name UserAuthentication -Type DWord -Value 0
shutdown /r /t 0

$Source = "https://github.com/Cohesity-Academy/labscripts/raw/refs/heads/main/theupgrader.ps1"
$Destination = "theupgrader.ps1"
Invoke-WebRequest -Uri $source -OutFile $Destination
./theupgrader.ps1
