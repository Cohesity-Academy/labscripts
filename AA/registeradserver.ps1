# usage: ./registeradserver.ps1 -vip clusername -username admin -password password -adserver servername

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter(Mandatory = $True)][string]$password, # local or AD domain password
    [Parameter(Mandatory = $True)][string]$adserver #Active Directory Server
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -password $password -quiet

Connect-CohesityCluster -Server $vip -Credential (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "LOCAL\$username", (ConvertTo-SecureString -AsPlainText "$password" -Force))
$source = get-cohesityprotectionsource -name $adserver
$id = $source.rootNode.id

apiauth -vip $vip -username $username -password $password
$myObject2 = @{
    "ownerEntity" = @{
                        "id" = $id
                    };
    "appEnvVec" = @(
                      29
                  )
}

api post /applicationSourceRegistration $myObject2
