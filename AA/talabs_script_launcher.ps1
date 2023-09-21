<#
TechAccelerator Labs Cloud Launcher
-----------------------------------
This is used to execute scripts that complete sections of the cloud storyboards. Multiple launcher scripts can be executed at the same time, however only one of each storyboard script can be executed at a time (and once executed, cannot be executed again in the same lab).

Requires a lab monitor file (talabs_script_monitor.txt) located on the local system ($scriptMonitorPath).  Format of that file is as follows:

script_launcher = false
azure_cloudarchive = false
azure_cloudspin_ondemand = false
azure_cloudspin_policy = false
azure_ce_deployment = false
azure_native_snapshot = false
azure_csm = false
azure_cloudtier = false
aws_cloudarchive = false
aws_cloudspin_ondemand = false
aws_cloudspin_policy = false
aws_ce_deployment = false
aws_native_snapshot = false
aws_csm = false
aws_rds = false
aws_cloudtier = false
gcp_cloudarchive = false
gcp_ce_deployment = false
gcp_native_snapshot = false
gcp_cloudtier = false
coh_runbook = false

Each azure/aws/gcp entry above (e.g. azure_cloudarchive) is the first argument to be provided to this script.  Based on that argument the appropriate script will be downloaded from the script repository and run (passing in the range of applicable CSP specific parameters - e.g. Azure Resource Group).

Added ability to run Cohesity script (non-cloud) by passing in coh_<scriptname> as the first argument.

This wrapper script and the subscript it launches both log run information to $logFilePath.
#>

#Global variables and actions
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
$scriptLocation = "C:\cohesity\"
$scriptUrl = "https://files.techaccelerator.com/cohesity/public/scripts/cloud/"
$scriptMonitorPath = "C:\cohesity\talabs_script_monitor.txt"

#Open the logging window
$tmpFilePath  = [System.IO.Path]::GetTempFileName()
Start-Process powershell "-NoExit -Command cls;Get-Content $tmpFilePath -Wait" -PassThru

#Logging
$logFilePath = "C:\scriptLogging"
if(!(test-path $logFilePath)) {
    New-Item -ItemType directory -Path C:\ScriptLogging
}
$date = (Get-Date).ToString()
$date = $date.Replace('/','_')
$date = $date.Replace(':','_')
$logFile = $logFilePath + "\" + $date.Replace('/','_') + ".log"
Write-Output "Log File: $logFile" | Out-File $tmpFilePath
Write-Output "Log File: $logFile" | Out-File $logFile

#Check script type and inputs 
$scriptToRun = $args[0]
if($scriptToRun -match "azure") {
    #Set Azure variables
    $scriptType = "azure"
    $azureResourceGroup = $args[1]
    $azureSubscription = $args[2]
    $azureTenant = $args[3]
    $azureApplication = $args[4]
    $azureApplicationKey = $args[5]
} else {
    if($scriptToRun -match "aws") {
        #Set AWS variables
        $scriptType = "aws"
        $awsResourceGroup = $args[1]
        $awsVpcId = $args[2]
        $awsSubnetId = $args[3]
        $awsNetworkSecurityGroup = $args[4]
        $awsRdsDatabaseInstanceId = $args[5]
        $awsAccessKeyId = $args[6]
        $awsSecretAccessKey = $args[7]
    } else {
        if($scriptToRun -match "gcp") {
            #Set GCP variables
            $scriptType = "gcp"
            $gcpResourceGroup = $args[1]
            $gcpUsername = $args[2]
        } else {
            if($scriptToRun -match "coh") {
                #Set GCP variables
                $scriptType = "coh"
                #Pass in any script arguments need as a comma separated list
                $scriptArgs = $args[1]
            } else{
                Write-Output "ERROR: Couldn't determine script type!" | Out-File $tmpFilePath
                Write-Output "ERROR: Couldn't determine script type!" | Out-File $logFile
            }
        }
    }
}

#Functions
Function Test-Module {
    param($name)
    if(-not(Get-Module -name $name)) { 
        if(Get-Module -ListAvailable | Where-Object { $_.name -eq $name }) {
            Import-Module -Name $name
            $true
        } else {$false}
    } else {$true}
}

Function Invoke-AzureScript {
    param($script,$azurerg,$azuresub,$azureten,$azureappid,$azureappkey,$azuresakey,[int]$mline,$mpath,$location,$url,$flog,$clog)
    #Check to see if this process is already running
    [string[]]$array = Get-Content -Path $mpath
    if ($array[$mline] -eq "$script = true") {
        #Script is already being run
        Write-Output "`nScript $script is already running!" | Out-File $clog -Append
        Write-Output "Script $script is already running!" | Out-File $flog -Append
    } else {
        if ($array[$mline] -eq "$script = done") {
            #Script has been previously run
            Write-Output "`nScript $script has already been run in this lab!" | Out-File $clog -Append
            Write-Output "Script $script has already been run in this lab!" | Out-File $flog -Append
        } else {
            #Script is not running and has not been previously run
            #Download script
            $scriptName = "talabs_$script.ps1"
            $scriptPath = $location + $scriptName
            $downloadUrl = $url + $scriptName
            Invoke-WebRequest $downloadUrl -OutFile $scriptPath
            #Execute script
            Write-Output "`nCalling script $script" | Out-File $clog -Append
            Write-Output "Calling script $script" | Out-File $flog -Append
            Set-MonitorFile -writeline $mline -text "$script = true" -file $mpath
            Invoke-Expression "& `"$scriptPath`" $azurerg $azuresub $azureten $azureappid $azureappkey"
            Write-Output "Completed: $script" | Out-File $clog -Append
            Set-MonitorFile -writeline $mline -text "$script = done" -file $mpath
            #Delete downloaded script
            Remove-Item -Path $scriptPath -Force
        }
    }
}

Function Invoke-AwsScript {
    param($script,$awsrsgrp,$awsvpc,$awssn,$awsnsg,$awsrdsdb,$awsac,$awssac,[int]$mline,$mpath,$location,$url,$flog,$clog)
    #Check to see if this process is already running
    [string[]]$array = Get-Content -Path $mpath
    if ($array[$mline] -eq "$script = true") {
        #Script is already being run
        Write-Output "`nScript $script is already running!" | Out-File $clog -Append
        Write-Output "Script $script is already running!" | Out-File $flog -Append
    } else {
        if ($array[$mline] -eq "$script = done") {
            #Script has been previously run
            Write-Output "`nScript $script has already been run in this lab!" | Out-File $clog -Append
            Write-Output "Script $script has already been run in this lab!" | Out-File $flog -Append
        } else {
            #Script is not running and has not been previously run
            #Download script
            $scriptName = "talabs_$script.ps1"
            $scriptPath = $location + $scriptName
            $downloadUrl = $url + $scriptName
            Invoke-WebRequest $downloadUrl -OutFile $scriptPath
            #Execute script
            Write-Output "`nCalling script $script" | Out-File $clog -Append
            Write-Output "Calling script $script" | Out-File $flog -Append
            Set-MonitorFile -writeline $mline -text "$script = true" -file $mpath
            Invoke-Expression "& `"$scriptPath`" $awsrsgrp $awsvpc $awssn $awsnsg $awsrdsdb $awsac $awssac"
            Write-Output "Completed: $script" | Out-File $clog -Append
            Set-MonitorFile -writeline $mline -text "$script = done" -file $mpath
            #Delete downloaded script
            Remove-Item -Path $scriptPath -Force
        }
    }
}

Function Invoke-GcpScript {
    param($script,$gcprsgrp,$gcpun,[int]$mline,$mpath,$location,$url,$flog,$clog)
    #Check to see if this process is already running
    [string[]]$array = Get-Content -Path $mpath
    if ($array[$mline] -eq "$script = true") {
        #Script is already being run
        Write-Output "`nScript $script is already running!" | Out-File $clog -Append
        Write-Output "Script $script is already running!" | Out-File $flog -Append
    } else {
        if ($array[$mline] -eq "$script = done") {
            #Script has been previously run
            Write-Output "`nScript $script has already been run in this lab!" | Out-File $clog -Append
            Write-Output "Script $script has already been run in this lab!" | Out-File $flog -Append
        } else {
            #Script is not running and has not been previously run
            #Download script
            $scriptName = "talabs_$script.ps1"
            $scriptPath = $location + $scriptName
            $downloadUrl = $url + $scriptName
            Invoke-WebRequest $downloadUrl -OutFile $scriptPath
            #Execute script
            Write-Output "`nCalling script $script" | Out-File $clog -Append
            Write-Output "Calling script $script" | Out-File $flog -Append
            Set-MonitorFile -writeline $mline -text "$script = true" -file $mpath
            Invoke-Expression "& `"$scriptPath`" $gcprsgrp $gcpun"
            Write-Output "Completed: $script" | Out-File $clog -Append
            Set-MonitorFile -writeline $mline -text "$script = done" -file $mpath
            #Delete downloaded script
            Remove-Item -Path $scriptPath -Force
        }
    }
}

Function Invoke-CohScript {
    param($script,$cohargs,[int]$mline,$mpath,$location,$url,$flog,$clog)
    #Check to see if this process is already running
    [string[]]$array = Get-Content -Path $mpath
    if ($array[$mline] -eq "$script = true") {
        #Script is already being run
        Write-Output "`nScript $script is already running!" | Out-File $clog -Append
        Write-Output "Script $script is already running!" | Out-File $flog -Append
    } else {
        if ($array[$mline] -eq "$script = done") {
            #Script has been previously run
            Write-Output "`nScript $script has already been run in this lab!" | Out-File $clog -Append
            Write-Output "Script $script has already been run in this lab!" | Out-File $flog -Append
        } else {
            #Script is not running and has not been previously run
            #Download script
            $scriptName = "talabs_$script.ps1"
            $scriptPath = $location + $scriptName
            $downloadUrl = $url + $scriptName
            Invoke-WebRequest $downloadUrl -OutFile $scriptPath
            #Execute script
            Write-Output "`nCalling script $script" | Out-File $clog -Append
            Write-Output "Calling script $script" | Out-File $flog -Append
            Set-MonitorFile -writeline $mline -text "$script = true" -file $mpath
            Invoke-Expression "& `"$scriptPath`" $cohargs"
            Write-Output "Completed: $script" | Out-File $clog -Append
            Set-MonitorFile -writeline $mline -text "$script = done" -file $mpath
            #Delete downloaded script
            Remove-Item -Path $scriptPath -Force
        }
    }
}

Function Test-AzureCli {
    param($flog,$clog,$mpath)
    #Azure CLI check
    Write-Output "`nChecking for Azure CLI ..." | Out-File $clog -Append
    $path = "C:\Program Files (x86)\Microsoft SDKs\Azure\CLI2\wbin\az.cmd"
    $verify = Test-Path $path -PathType Leaf
    if ($verify -eq $true) {
        #Azure CLI is installed
        Write-Output "Azure CLI is installed" | Out-File $clog -Append
    } else {
        #Install Azure CLI
        Write-Output "Azure CLI is not installed, installing now ..." | Out-File $clog -Append
        Write-Output "Azure CLI size is roughly 56000000 bytes" | Out-File $clog -Append
        Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm .\AzureCLI.msi
        #Check for successful installation
        Start-Sleep -Seconds 3
        $verify = Test-Path $path -PathType Leaf
        if ($verify -eq $true) {
            #Azure CLI is installed
            Write-Output "Azure CLI is installed" | Out-File $clog -Append
            Write-Output "Azure CLI is installed" | Out-File $flog -Append
        } else {
            #Azure CLI install didn't complete, retry one time
            Write-Output "Azure CLI install failed, retrying 1 time ..." | Out-File $clog -Append
            Write-Output "Azure CLI install failed, retrying 1 time ..." | Out-File $flog -Append
            Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm .\AzureCLI.msi
            #Check for successful installation
            Start-Sleep -Seconds 3
            $verify = Test-Path $path -PathType Leaf
            if ($verify -eq $true) {
                #Azure CLI is installed
                Write-Output "Azure CLI is installed" | Out-File $clog -Append
                Write-Output "Azure CLI is installed" | Out-File $flog -Append 
            } else {
                #Installation failed, exit script execution
                Write-Output "Azure CLI install failed!" | Out-File $clog -Append
                Write-Output "Azure CLI install failed!" | Out-File $flog -Append
                #Cleanup and exit
                [string[]]$arrayFromFile = Get-Content -Path $mpath
                Set-ScriptMonitorStop -array $arrayFromFile -Path $mpath
                Exit  
            }
        }
    }
}

Function Test-AzModule {
    param($flog,$clog)
    #Az module check
    Write-Output "`nChecking for Az module ..." | Out-File $clog -Append
    try {
        Import-Module Az
        Write-Output "Az module is loaded" | Out-File $clog -Append
    } catch {
        Write-Output "Az module is not available, installing now ..." | Out-File $clog -Append
        Install-Module Az -Force
        Write-Output "Az module installed, importing module ..." | Out-File $clog -Append
        Import-Module Az
        Write-Output "Az module is now available"  | Out-File $clog -Append
        Write-Output "Installed Az PowerShell module" | Out-File $flog -Append 
    }
}

Function Test-AwsModule {
    param($flog,$clog)
    #AWS.Tools.Common module check
    Write-Output "`nChecking for AWS.Tools.Common module ..." | Out-File $clog -Append
    $verify = Test-Module -name "AWS.Tools.Common"
    if ($verify -eq $true) {
        #AWS.Tools.Common module is loaded
        Write-Output "AWS.Tools.Common module is loaded" | Out-File $clog -Append
    } else {
        #Install AWS.Tools.Common module
        Write-Output "AWS.Tools.Common module is not available, installing now ..." | Out-File $clog -Append
        Install-Module -Name "AWS.Tools.Common"
        Write-Output "AWS.Tools.Common module installed, importing module ..." | Out-File $clog -Append
        Import-Module -Name "AWS.Tools.Common"
        Write-Output "AWS.Tools.Common module is now available"  | Out-File $clog -Append
        Write-Output "Installed AWS.Tools.Common PowerShell module" | Out-File $flog -Append    
    }
    #AWS.Tools.EC2 module check
    Write-Output "`nChecking for AWS.Tools.EC2 module ..." | Out-File $clog -Append
    $verify = Test-Module -name "AWS.Tools.EC2"
    if ($verify -eq $true) {
        #AWS.Tools.EC2 module is loaded
        Write-Output "AWS.Tools.EC2 module is loaded" | Out-File $clog -Append
    } else {
        #Install AWS.Tools.EC2 module
        Write-Output "AWS.Tools.EC2 module is not available, installing now ..." | Out-File $clog -Append
        Install-Module -Name "AWS.Tools.EC2"
        Write-Output "AWS.Tools.EC2 module installed, importing module ..." | Out-File $clog -Append
        Import-Module -Name "AWS.Tools.EC2"
        Write-Output "AWS.Tools.EC2 module is now available"  | Out-File $clog -Append
        Write-Output "Installed AWS.Tools.EC2 PowerShell module" | Out-File $flog -Append    
    }
}

Function Test-GcpModule {
    param($flog,$clog)
    #GoogleCloud module check
    $Env:GCLOUD_SDK_INSTALLATION_NO_PROMPT = "true"
    Write-Output "`nChecking for GoogleCloud ..." | Out-File $clog -Append
    $verify = Test-Module -name "GoogleCloud"
    if ($verify -eq $true) {
        #GoogleCloud module is loaded
        Write-Output "GoogleCloud module is loaded" | Out-File $clog -Append
    } else {
        #Install GoogleCloud module
        Write-Output "GoogleCloud module is not available, installing now ..." | Out-File $clog -Append
        Install-Module -Name "GoogleCloud" -Force
        Write-Output "GoogleCloud module installed, importing module ..." | Out-File $clog -Append
        Import-Module -Name "GoogleCloud" -Force
        Write-Output "GoogleCloud module is now available"  | Out-File $clog -Append
        Write-Output "Installed GoogleCloud PowerShell module" | Out-File $flog -Append    
    }
}

Function Set-MonitorFile {
    param([int]$writeline,$text,$file)
    #Update the monitor file
    [string[]]$marray = Get-Content -Path $file
    [int]$line = 0
    foreach ($i in $marray) {
        if ($line -eq 0) {
            if ($line -eq $writeline) {
                Set-Content -Path $file -Value $text
                $line++
            } else {
                Set-Content -Path $file -Value $i
                $line++
            }
        } else {
            if ($line -eq $writeline) {
                Add-Content -Path $file -Value $text
                $line++
            } else {
                Add-Content -Path $file -Value $i
                $line++
            }  
        }
    }
}

Function Set-ScriptMonitorStart {
    param($path,$flog,$clog)
    [string[]]$array = Get-Content -Path $path
    #Check for existing script launcher
    if ($array[0] -match "false") {
        #Script launcher is not currently running
        Write-Output "Script launcher is not already running" | Out-File $flog -Append
        $newText = "script_launcher = true"
        Set-MonitorFile -writeline 0 -text "$newText" -file $path
    } else {
        #Script launcher is already running
        Write-Output "Script launcher is already running!" | Out-File $clog -Append
        Write-Output "Script launcher is already running!" | Out-File $flog -Append
        exit
    }
}

Function Set-ScriptMonitorStop {
    param($path)
    $newText = "script_launcher = false"
    Set-MonitorFile -writeline 0 -text "$newText" -file $path
}

#Get mline number
[string[]]$arrayFromFile = Get-Content -Path $scriptMonitorPath
$pattern = "$scriptToRun = \w{4,5}"
foreach ($item in $arrayFromFile) {
    if ($item -match $pattern) {
        $monitorLine = [array]::indexof($arrayFromFile,$item)
        Write-Output "Found index of $item" | Out-File $logFile -Append
    } else {
        Write-Output "Cloud not find index of $item" | Out-File $logFile -Append
    }
}

#Update the script monitor
Set-ScriptMonitorStart -Path $scriptMonitorPath -flog $logFile -clog $tmpFilePath

#Run the script
if ($scriptType -eq "azure") {
    #Check prerequisites
    Test-AzureCli -flog $logFile -clog $tmpFilePath -mpath $scriptMonitorPath
    Test-AzModule -flog $logFile -clog $tmpFilePath
    #Call script
    Invoke-AzureScript -script $scriptToRun `
    -azurerg $azureResourceGroup `
    -azuresub $azureSubscription `
    -azureten $azureTenant `
    -azureappid $azureApplication `
    -azureappkey $azureApplicationKey `
    -azuresakey $azureStorageAccessKey `
    -mline $monitorLine `
    -mpath $scriptMonitorPath `
    -location $scriptLocation `
    -url $scriptUrl `
    -flog $logFile `
    -clog $tmpFilePath
} else {
    if ($scriptType -eq "aws") {
        #Check prerequisites
        Test-AwsModule -flog $logFile -clog $tmpFilePath
        #Call script
        Invoke-AwsScript -script $scriptToRun `
        -awsrsgrp $awsResourceGroup `
        -awsvpc $awsVpcId `
        -awssn $awsSubnetId `
        -awsnsg $awsNetworkSecurityGroup `
        -awsrdsdb $awsRdsDatabaseInstanceId `
        -awsac $awsAccessKeyId `
        -awssac $awsSecretAccessKey `
        -mline $monitorLine `
        -mpath $scriptMonitorPath `
        -location $scriptLocation `
        -url $scriptUrl `
        -flog $logFile `
        -clog $tmpFilePath
    } else {
        if ($scriptType -eq "gcp") {
            #Check prerequisites
            Test-GcpModule -flog $logFile -clog $tmpFilePath
            #Call script
            Invoke-GcpScript -script $scriptToRun `
            -gcprsgrp $gcpResourceGroup `
            -gcpun $gcpUsername `
            -mline $monitorLine `
            -mpath $scriptMonitorPath `
            -location $scriptLocation `
            -url $scriptUrl `
            -flog $logFile `
            -clog $tmpFilePath
        } else {
            if ($scriptType -eq "coh") {
                #Call script
                Invoke-CohScript -script $scriptToRun `
                -cohargs $scriptArgs `
                -mline $monitorLine `
                -mpath $scriptMonitorPath `
                -location $scriptLocation `
                -url $scriptUrl `
                -flog $logFile `
                -clog $tmpFilePath
            } else {
                Write-Output "ERROR: Couldn't determine script type!" | Out-File $logFile -Append
                Write-Output "ERROR: Couldn't determine script type!" | Out-File $tmpFilePath -Append
            }
        }
    }
}

#Update the script monitor
Set-ScriptMonitorStop -Path $scriptMonitorPath

#Close the PowerShell window
stop-process -Id $PID