# usage: ./backupolicy.ps1 -vip mycluster -username myusername -password mypassword -Name "policyname" -frequency frequencyinminutes

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter(Mandatory = $True)][string]$password,  # local or AD domain password
    [Parameter(Mandatory = $True)][int]$frequency,  # backup in min   
    [Parameter(Mandatory = $True)][string]$name  # name of policy
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -password $password -quiet

$policyParams = @{
    "backupPolicy" = @{
        "regular" = @{
            "incremental" = @{
                "schedule" = @{
                    "unit" = "Minutes";
                    "minuteSchedule" = @{
                        "frequency" = $frequency
                    }
                }
            };
            "retention" = @{
                "unit" = "Days";
                "duration" = 20
            }
        }
    };
    "id" = $null;
    "name" = "$name";
    "description" = $null;
    "remoteTargetPolicy" = @{};
    "retryOptions" = @{
        "retries" = 3;
        "retryIntervalMins" = 5
    }
}

$newpol = api post -v2 data-protect/policies $policyParams
