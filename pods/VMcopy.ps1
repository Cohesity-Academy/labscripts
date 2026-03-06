# ===== CONFIG =====
$sourceHost = "192.168.10.6"
$destinationHost = "192.168.10.4"
$username = "root"
$datastore = "datastore1"

$vmFolders = @(
    "AD-Server-1",
    "App-Server-1",
    "Isilon",
    "MSSQL-Server-1",
    "NFS-Server-1",
    "Cohesity-esx"
)

# ===== COPY PROCESS =====

foreach ($vm in $vmFolders) {

    Write-Host "Copying $vm..." -ForegroundColor Cyan

    $sourcePath = "/vmfs/volumes/$datastore/$vm"
    $destinationPath = "/vmfs/volumes/$datastore/"

    scp -r "${username}@${sourceHost}:${sourcePath}" `
           "${username}@${destinationHost}:${destinationPath}"

    if ($LASTEXITCODE -eq 0) {
        Write-Host "$vm copied successfully." -ForegroundColor Green
    }
    else {
        Write-Host "Error copying $vm" -ForegroundColor Red
        break
    }

    Write-Host "--------------------------------------"
}

Write-Host "All VM copy operations completed."