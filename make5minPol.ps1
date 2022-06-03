. .\cohesity-api.ps1

[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter(Mandatory = $True)][string]$password = '',  # local or AD domain password
)
apiauth -vip $vip -username $username -domain local -password $password

$policyParams = @{
    "backupPolicy" = @{
        "regular" = @{
            "incremental" = @{
                "schedule" = @{
                    "unit" = "Minutes";
                    "minuteSchedule" = @{
                        "frequency" = 5
                    }
                }
            };
            "retention" = @{
                "unit" = "Days";
                "duration" = 1
            }
        }
    };
    "id" = $null;
    "name" = "5 minute policy";
    "description" = $null;
    "remoteTargetPolicy" = @{};
    "retryOptions" = @{
        "retries" = 3;
        "retryIntervalMins" = 5
    }
}

$newpol = api post -v2 data-protect/policies $policyParams
