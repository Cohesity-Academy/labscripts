#requires -Version 5.1
#requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

### check whether Visual C++ x86 is already installed
$Registry = [Microsoft.Win32.RegistryKey]::OpenBaseKey(
    [Microsoft.Win32.RegistryHive]::LocalMachine,
    [Microsoft.Win32.RegistryView]::Registry32
)

$Runtime = $null
$AlreadyInstalled = $false

try {
    $Runtime = $Registry.OpenSubKey(
        'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x86'
    )

    $AlreadyInstalled = (
        $null -ne $Runtime -and
        $Runtime.GetValue('Installed') -eq 1
    )
}
finally {
    if ($null -ne $Runtime) { $Runtime.Dispose() }
    $Registry.Dispose()
}

if ($AlreadyInstalled) {
    Write-Host "Visual C++ x86 is already installed. Skipping installation." -ForegroundColor Green
    exit 0
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Installers = @(
    @{
        Name = "Visual C++ 2015-2022 Redistributable (x86)"
        Url  = "https://aka.ms/vs/17/release/vc_redist.x86.exe"
        File = "vc_redist.x86.exe"
    }
)

$TempFolder = Join-Path ([System.IO.Path]::GetTempPath()) "VCredist-$([guid]::NewGuid())"
New-Item -Path $TempFolder -ItemType Directory -Force | Out-Null

$RebootRequired = $false

try {
    foreach ($Installer in $Installers) {
        $InstallerPath = Join-Path $TempFolder $Installer.File

        Write-Host "Downloading $($Installer.Name)..."
        Invoke-WebRequest -Uri $Installer.Url -OutFile $InstallerPath -UseBasicParsing

        $Signature = Get-AuthenticodeSignature -FilePath $InstallerPath
        if ($Signature.Status -ne "Valid" -or $Signature.SignerCertificate.Subject -notmatch "Microsoft") {
            throw "Microsoft signature validation failed for $($Installer.File)."
        }

        Write-Host "Installing $($Installer.Name)..."
        $Process = Start-Process -FilePath $InstallerPath `
            -ArgumentList "/install", "/quiet", "/norestart" `
            -Wait -PassThru

        switch ($Process.ExitCode) {
            0 {
                Write-Host "$($Installer.Name) installed successfully." -ForegroundColor Green
            }
            1638 {
                Write-Host "$($Installer.Name) or a newer version is already installed." -ForegroundColor Yellow
            }
            3010 {
                Write-Host "$($Installer.Name) installed successfully; a reboot is required." -ForegroundColor Yellow
                $RebootRequired = $true
            }
            default {
                throw "$($Installer.Name) installation failed with exit code $($Process.ExitCode)."
            }
        }
    }
}
finally {
    if (Test-Path $TempFolder) {
        Remove-Item -Path $TempFolder -Recurse -Force
    }
}

if ($RebootRequired) {
    Write-Host "Installation completed. Restart Windows to finish applying the changes." -ForegroundColor Yellow
}
else {
    Write-Host "Visual C++ Redistributable installation completed." -ForegroundColor Green
}
