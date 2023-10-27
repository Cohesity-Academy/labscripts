# usage: ./azuresource.ps1 -vip clusername -username admin -password password -subscriptionId "" -applicationId "" -applicationKey "" -tenantId ""

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter(Mandatory = $True)][string]$password, # local or AD domain password
    [Parameter(Mandatory = $True)][string]$subscriptionId,  # Azure Subscription
    [Parameter(Mandatory = $True)][string]$applicationId,  # Azure Ent Application
    [Parameter(Mandatory = $True)][string]$applicationKey,  # Application Private key
    [Parameter(Mandatory = $True)][string]$tenantId  # Azure Tenant
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -password $password -quiet

# authenticate
apiauth -vip $vip -username $username -domain $domain -password $password -quiet


$myObject = @{
    "entity" = @{
                   "type" = 8;
                   "azureEntity" = @{
                                       "type" = 0;
                                       "name" = "$subscriptionId";
                                       "id" = "/subscriptions/$subscriptionId"
                                   }
               };
    "entityInfo" = @{
                       "type" = 8;
                       "credentials" = @{
                                           "cloudCredentials" = @{
                                                                    "azureCredentials" = @{
                                                                                             "subscriptionType" = 1;
                                                                                             "subscriptionId" = "$subscriptionId";
                                                                                             "applicationId" = "$applicationId";
                                                                                             "applicationKey" = "$applicationKey";
                                                                                             "tenantId" = "$tenantId"
                                                                                         }
                                                                }
                                       };
                       "_isSelected" = $false
                   };
    "registeredEntityParams" = @{
                                   "isSpaceThresholdEnabled" = $false;
                                   "throttlingPolicy" = @{
                                                            "isThrottlingEnabled" = $false;
                                                            "isDatastoreStreamsConfigEnabled" = $false;
                                                            "datastoreStreamsConfig" = @{

                                                                                       }
                                                        };
                                   "vmwareParams" = @{

                                                    }
                               };
    "_subscriptionType" = 1
}

api POST /backupsources $myObject
