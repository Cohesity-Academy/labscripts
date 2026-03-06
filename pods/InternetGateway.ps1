# ==========================
# CONFIGURATION
# ==========================
$WifiAdapterName     = "Wi-Fi"
$EthernetAdapterName = "HostNIC"

$StaticIP   = "192.168.10.8"
$SubnetMask = "255.255.255.0"
$DNS        = "192.168.10.10"

# ==========================
# FUNCTIONS
# ==========================
function Get-NetConnectionByName {
    param ($Name)

    $hnet = New-Object -ComObject HNetCfg.HNetShare
    foreach ($conn in $hnet.EnumEveryConnection()) {
        $props = $hnet.NetConnectionProps($conn)
        if ($props.Name -eq $Name) {
            return @{ HNet = $hnet; Conn = $conn }
        }
    }
    return $null
}

function Disable-ICS {
    param ($Name)

    $net = Get-NetConnectionByName $Name
    if ($net) {
        $cfg = $net.HNet.INetSharingConfigurationForINetConnection($net.Conn)
        if ($cfg.SharingEnabled) {
            Write-Host "Disabling ICS on $Name..."
            $cfg.DisableSharing()
            Start-Sleep -Seconds 3
        }
    }
}

function Enable-ICS {
    param ($Name)

    $net = Get-NetConnectionByName $Name
    if ($net) {
        $cfg = $net.HNet.INetSharingConfigurationForINetConnection($net.Conn)
        Write-Host "Enabling ICS on $Name..."
        $cfg.EnableSharing(0) # 0 = Public (Internet)
        Start-Sleep -Seconds 3
    }
}

# ==========================
# EXECUTION
# ==========================

Write-Host "Resetting Internet Connection Sharing..."

Disable-ICS -Name $WifiAdapterName
Enable-ICS  -Name $WifiAdapterName

Write-Host "Configuring static IP on $EthernetAdapterName..."

# Remove existing IPs and gateways
Get-NetIPAddress -InterfaceAlias $EthernetAdapterName -ErrorAction SilentlyContinue |
    Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

Get-NetRoute -InterfaceAlias $EthernetAdapterName -ErrorAction SilentlyContinue |
    Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue

# Set static IP (no gateway)
New-NetIPAddress `
    -InterfaceAlias $EthernetAdapterName `
    -IPAddress $StaticIP `
    -PrefixLength 24

# Set DNS
Set-DnsClientServerAddress `
    -InterfaceAlias $EthernetAdapterName `
    -ServerAddresses $DNS

Write-Host "Done."
