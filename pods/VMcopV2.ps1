Import-Module Posh-SSH

# ===== CONFIG =====
$sourceHost = "192.168.10.6"
$destinationHost = "192.168.10.4"
$username = "root"
$datastore = "datastore1"

# VM folders to copy
$vmFolders = @(
    "AD-Server-1",
    "App-Server-1",
    "Isilon",
    "MSSQL-Server-1",
    "NFS-Server-1",
    "Cohesity-esx"
)

# ===== PASSWORDS =====
$sourcePassword = "Acme123!"  # ESXi source password
$destinationPassword = "Acme123!"  # ESXi destination password

# Convert to SecureString and PSCredential objects
$sourceSecure = ConvertTo-SecureString $sourcePassword -AsPlainText -Force
$sourceCredential = New-Object System.Management.Automation.PSCredential ($username, $sourceSecure)

$destinationSecure = ConvertTo-SecureString $destinationPassword -AsPlainText -Force
$destinationCredential = New-Object System.Management.Automation.PSCredential ($username, $destinationSecure)

# ===== CONNECT TO SOURCE ESXi =====
$session = New-SSHSession -ComputerName $sourceHost -Credential $sourceCredential -AcceptKey

if ($session.SessionId -ge 0) {

    foreach ($vm in $vmFolders) {

        Write-Host "Copying $vm from $sourceHost to $destinationHost..." -ForegroundColor Cyan

        # SCP command with password injection using sshpass (if installed on ESXi)
        # If ESXi doesn't have sshpass, it will prompt for password manually
        $command = "scp -r /vmfs/volumes/$datastore/$vm $username@$destinationHost{:}/vmfs/volumes/$datastore/"

        $result = Invoke-SSHCommand -SessionId $session.SessionId -Command $command -TimeOut 0

        $result.Output

        if ($result.ExitStatus -eq 0) {
            Write-Host "$vm copied successfully." -ForegroundColor Green
        }
        else {
            Write-Host "Error copying $vm" -ForegroundColor Red
            break
        }

        Write-Host "----------------------------------"
    }

    Remove-SSHSession -SessionId $session.SessionId
}
else {
    Write-Host "Failed to establish SSH session to $sourceHost." -ForegroundColor Red
}