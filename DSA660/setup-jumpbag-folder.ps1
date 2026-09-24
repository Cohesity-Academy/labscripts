# ============================================================
# Digital Jump Bag Builder
# Creates a folder structure of FAKE placeholder assets for a
# Minimum Viable Response Capability (MVRC) jump bag.
# All ISOs/ZIPs/OVAs are randomly-generated dummy data, not real
# software. Hashes in the validation CSV are placeholders only.
# ============================================================

$targetDrive = "c:"
$root = "$targetDrive\Digital-JumpBag"

# ------------------------------------------------------------
# Preflight: confirm the S: volume actually exists/is mapped
# ------------------------------------------------------------
if (-not (Test-Path "$targetDrive\")) {
 throw "Drive $targetDrive is not available. Make sure the S: volume is mounted/mapped before running this script. Aborting."
}

$folders = @(
 "01_Golden_Images_and_ISOs",
 "02_Application_Installers",
 "03_Security_Tools",
 "04_Documentation_and_Playbooks",
 "05_Dial_Tone_Apps"
)

# ------------------------------------------------------------
# Preflight: estimate total size and check free disk space
# ------------------------------------------------------------
$plannedFilesMB = @(450, 600, 350, 125, 210, 275, 40, 800, 750, 400, 140, 190)
$totalMB = ($plannedFilesMB | Measure-Object -Sum).Sum
$totalGB = [math]::Round($totalMB / 1024, 2)

$drive = Get-PSDrive -Name $targetDrive.TrimEnd(":")
$freeMB = [math]::Round($drive.Free / 1MB, 0)

Write-Host "This script will write approximately $totalMB MB (~$totalGB GB) of fake data to $targetDrive"
Write-Host "Free space on drive $targetDrive`: $freeMB MB"

if ($freeMB -lt ($totalMB * 1.1)) {
 throw "Not enough free disk space. Need at least $([math]::Ceiling($totalMB * 1.1)) MB, but only $freeMB MB is available. Aborting."
}

foreach ($folder in $folders) {
 New-Item -ItemType Directory -Path "$root\$folder" -Force | Out-Null
}

####################################################
# Helper Function
####################################################

function New-FakeFile {
 param (
 [Parameter(Mandatory = $true)]
 [string]$Path,

 [Parameter(Mandatory = $true)]
 [ValidateRange(1, [int]::MaxValue)]
 [int64]$SizeMB
 )

 # Single Random instance reused across the whole write, so we
 # don't risk clock-seeded collisions producing identical bytes
 # across chunks (a real risk when instantiating Random in a loop).
 $rng = [System.Random]::new()
 $bytes = New-Object byte[] (1024 * 1024)
 $stream = $null

 try {
 $stream = [System.IO.File]::Create($Path)
 for ($i = 0; $i -lt $SizeMB; $i++) {
 $rng.NextBytes($bytes)
 $stream.Write($bytes, 0, $bytes.Length)
 }
 }
 finally {
 if ($stream) { $stream.Close() }
 }
}

####################################################
# Golden Images
####################################################

New-FakeFile "$root\01_Golden_Images_and_ISOs\Windows_Server_2025_Golden.iso" 450
New-FakeFile "$root\01_Golden_Images_and_ISOs\VMware_ESXi_Golden.iso" 600
New-FakeFile "$root\01_Golden_Images_and_ISOs\Linux_Recovery_Image.iso" 350

# NOTE: Hash values below are PLACEHOLDERS for demo purposes only.
# They are not real SHA256 hashes of the generated files.
@"
Image Name,Version,Validation Date,SHA256
Windows Server 2025,25.1,2026-08-15,A73B...
VMware ESXi,8.0U2,2026-08-15,D92F...
Ubuntu Recovery,24.04,2026-08-15,E11A...
"@ | Out-File "$root\01_Golden_Images_and_ISOs\Image_Validation_Hashes.csv" -Encoding utf8

####################################################
# Application Installers
####################################################

New-FakeFile "$root\02_Application_Installers\ERP_Server_Installer.zip" 125
New-FakeFile "$root\02_Application_Installers\CRM_Platform_Installer.zip" 210

@"
{
 "Domain":"corp.contoso.local",
 "IdentityProvider":"Active Directory",
 "OU":"ServiceAccounts"
}
"@ | Out-File "$root\02_Application_Installers\Identity_Service_Config.json" -Encoding utf8

@"
<dns-config>
 <primary>10.20.0.10</primary>
 <secondary>10.20.0.11</secondary>
</dns-config>
"@ | Out-File "$root\02_Application_Installers\DNS_Server_Config.xml" -Encoding utf8

####################################################
# Security Tools
####################################################

New-FakeFile "$root\03_Security_Tools\Malware_Scanner_Toolkit.zip" 275
New-FakeFile "$root\03_Security_Tools\IOC_Collection_Scripts.zip" 40
New-FakeFile "$root\03_Security_Tools\Vulnerability_Scanner.iso" 800

@"
Toolkit Inventory
=================

EDR Validation Utility
YARA Scanner
Memory Analysis Toolkit
Offline Antivirus Engine
Patch Validation Scripts
"@ | Out-File "$root\03_Security_Tools\Security_Toolkit_Readme.txt" -Encoding utf8

####################################################
# Documentation & Playbooks
####################################################

@"
INCIDENT RESPONSE PLAYBOOK

1. Activate Cyber Response Team
2. Validate Scope
3. Establish Clean Room
4. Build MVRC
5. Restore Critical Services
6. Begin Forensics Investigation
"@ | Out-File "$root\04_Documentation_and_Playbooks\Incident_Response_Playbook.txt" -Encoding utf8

@"
Network Diagram Summary

Primary DC
192.168.10.0/24

Recovery Network
10.55.0.0/24

Firewall Gateways
FW-01
FW-02
"@ | Out-File "$root\04_Documentation_and_Playbooks\Network_Diagram.txt" -Encoding utf8

# Saved as .txt (not .doc) since the content is plain text, not a
# real Word binary/OOXML file. Ask if you'd like an actual .docx.
@"
AD Recovery Guide

Step 1: Build isolated domain controllers.
Step 2: Validate backup media.
Step 3: Restore critical identities.
"@ | Out-File "$root\04_Documentation_and_Playbooks\AD_Recovery_Guide.txt" -Encoding utf8

@"
Name,Role,Phone
Sarah Nguyen,CISO,555-1000
Michael Torres,Infrastructure Director,555-1001
Chris Miller,Security Lead,555-1002
"@ | Out-File "$root\04_Documentation_and_Playbooks\Emergency_Contacts.csv" -Encoding utf8

####################################################
# Dial Tone Apps
####################################################

New-FakeFile "$root\05_Dial_Tone_Apps\Emergency_Email_Server.ova" 750
New-FakeFile "$root\05_Dial_Tone_Apps\Backup_DNS_Appliance.ova" 400
New-FakeFile "$root\05_Dial_Tone_Apps\Temporary_IAM_Service.zip" 140
New-FakeFile "$root\05_Dial_Tone_Apps\Secure_Messaging_Server.zip" 190

####################################################
# Summary File
####################################################

@"
DIGITAL JUMP BAG

Purpose:
Provide validated resources needed to establish
a Minimum Viable Response Capability (MVRC)
during a cyber incident.

Contents:
- Golden Images
- Application Installers
- Security Tooling
- Documentation
- Dial Tone Services

NOTE: This bag was generated with placeholder/fake data
for demonstration or testing purposes.
"@ | Out-File "$root\README.txt" -Encoding utf8

Write-Host "Digital Jump Bag created successfully at $root ($totalGB GB of fake data)."
