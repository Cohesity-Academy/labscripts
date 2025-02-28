#.\sshcmds.ps1 -ip "192.168.1.1" -username "admin" -password "password" -commands "iris_cli,admin,cohesity123,cluster secure-shell enable=false"
# must have posh-ssh installed (install-module -name posh-ssh -scope Allusers -Force)


[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$ip,  # ip of the cluster to connect to
    [Parameter(Mandatory = $True)][string]$username,  # support username
    [Parameter(Mandatory = $True)][string]$password, # support password
    [Parameter(Mandatory = $True)][string]$commands  # comma-separated list of commands
)
#remove old sessions and trusts
Remove-SSHSession -SessionId 0
Remove-SSHTrustedHost -HostName $ip
# source the cohesity-api helper code
$SessionSSH = New-SSHSession -AcceptKey -ComputerName $ip -Credential (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "$username", (ConvertTo-SecureString -AsPlainText "$password" -Force))
Get-SSHSession | fl
$session = Get-SSHSession -Index 0
Start-Sleep 3
$stream = $session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
$outputFile = "C:\output.txt"

# Loop through each command in the comma-separated list and send it to the SSH stream
$command = $commands -split ","
ForEach ($cmd in $command) {
    Start-Sleep 3
    $stream.Write("$cmd`n")
    Start-Sleep 1
    $output = $stream.read()
    $output | Out-File -FilePath $outputFile -Append
}
