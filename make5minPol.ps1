. .\cohesity-api.ps1
apiauth -vip ve2 -username admin -domain local -password $null

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
