$path = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"
Set-ItemProperty -Path $path -Name UserAuthentication -Type DWord -Value 0
$nic = get-netadapter
Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ServerAddresses ("192.168.1.10")
$Source = "https://github.com/Cohesity-Academy/labscripts/raw/refs/heads/main/theupgrader.ps1"
$Destination = "c:\users\coh-student.cohesitylabs\documents\scripts\theupgrader.ps1"
Invoke-WebRequest -Uri $source -OutFile $Destination
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File c:\users\coh-student.cohesitylabs\documents\scripts\theupgrader.ps1"
$trigger = New-ScheduledTaskTrigger -AtLogon
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType Password
Register-ScheduledTask -TaskName "Upgrade Software" -Action $action -Trigger $trigger -Principal $principal -Settings $settings
ssmsfix.ps1
$Source2 = "https://github.com/Cohesity-Academy/labscripts/raw/refs/heads/main/ssmsfix.ps1"
$Destination2 = "c:\users\coh-student.cohesitylabs\documents\scripts\ssmsfix.ps1"
Invoke-WebRequest -Uri $source2 -OutFile $Destination2
$action2 = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File c:\users\coh-student.cohesitylabs\documents\scripts\ssmsfix.ps1"
$trigger2 = New-ScheduledTaskTrigger -AtLogon
$settings2 = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
$principal2 = New-ScheduledTaskPrincipal -UserId "cohesitylabs\coh-student" -LogonType Password
Register-ScheduledTask -TaskName "Fix SSMS" -Action $action2 -Trigger $trigger2 -Principal $principal2 -Settings $settings2
shutdown /r /t 0
