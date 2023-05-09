### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$ip,            # ip address of the node
    [Parameter(Mandatory = $True)][string]$netmask,       # subnet mask
    [Parameter(Mandatory = $True)][string]$gateway,       # default gateway
    [Parameter(Mandatory = $True)][String[]]$dnsServers,  # dns servers
    [Parameter(Mandatory = $True)][String[]]$ntpServers,  # ntp servers
    [Parameter(Mandatory = $True)][string]$clusterName,   # Cohesity cluster name
    [Parameter(Mandatory = $True)][string]$clusterDomain, # DNS domain of Cohesity cluster
    [Parameter(Mandatory = $True)][string]$pwd,           # new admin password
    [Parameter(Mandatory = $True)][string]$adminEmail,    # admin email address
    [Parameter(Mandatory = $True)][string]$adDomain,      # AD domain to join
    [Parameter(Mandatory = $True)][array]$preferredDC,   # preferred domain controller
    [Parameter()][string]$adOu = 'Computers',             # canonical name of container/OU
    [Parameter(Mandatory = $True)][string]$adAdmin,       # AD admin account name
    [Parameter(Mandatory = $True)][string]$adPwd,         # AD admin password
    [Parameter(Mandatory = $True)][string]$adAdminGroup,  # AD admin group to add
    [Parameter(Mandatory = $True)][string]$timezone,      # timezone
    [Parameter(Mandatory = $True)][string]$smtpServer,    # smtp server address
    [Parameter(Mandatory = $True)][string]$supportPwd,    # support account new ssh password
    [Parameter(Mandatory = $True)][string]$alertEmail     # email address for critical alerts
)

$synced = $false
while($synced -eq $false){
    Start-Sleep -Seconds 10
    apiauth -vip $ip -username admin -password admin -quiet
    if($AUTHORIZED -eq $true){
        $stat = api get /nexus/cluster/status
        if($stat.isServiceStateSynced -eq $true){
            $synced = $true
        }
    }    
}
