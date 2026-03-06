# ===============================
# Install Posh-ssh if missing (silent)
# ===============================
if (-not (Get-Module -ListAvailable -Name posh-ssh)) {

    Write-Host "Installing Posh-sshI..." -ForegroundColor Yellow

    if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    }

    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

    Install-Module posh-ssh `
        -Scope CurrentUser `
        -Force `
        -AllowClobber `
        -Confirm:$false
}

Import-Module posh-ssh


# ===============================
# Switch re-configuration
# ===============================

.\sshcmds.ps1 -ip "192.168.10.1" -username "admin" -password "admin" -commands "enable,configure terminal,interface eth-0-10,no shutdown,exit,exit,exit"
.\sshcmds.ps1 -ip "192.168.10.2" -username "admin" -password "admin" -commands "enable,configure terminal,interface eth-0-10,no shutdown,exit,exit,exit"

# ===============================
# Port Interface re-configuration options
# ===============================

#  access-group          Access group
#  arp                   Address Resolution Protocol (ARP)
#  auto-negotiate-mode   Specifies the port auto negotiate mode
#  bandwidth             Set bandwidth informational parameter
#  bfd                   Bidirectional Forwarding Detection (BFD)
#  carrier               Carrier layer
#  channel-group         LACP channel commands
#  description           Interface specific description
#  dhcp                  Specify DHCP configuration
#  dhcp-server           Specify DHCP server parameter
#  dhcpv6                Specify DHCPv6 parameter
#  dhcpv6-server         Specify DHCPv6 server parameter
#  distribute-weight     Set a distribute-weight of agg member port
#  do                    To run exec commands in config mode
#  dot1q                 Specify 802.1Q configuration information
#  dot1x                 IEEE 802.1X Port-Based Access Control
#  duplex                Set duplex to interface
#  efd                   Elephant flow detect
#  end                   End current mode and change to EXEC mode
#  errdisable            Error disable
#  exit                  End current mode and down to previous mode
#  fast-link             config fast-link
#  fec                   Set FEC mode of interface
#  ffe                   Set ffe to interface
#  flow-statistics       Port flow statistics
#  flowcontrol           Set flowcontrol to interface
#  group-speed           Speed of all interface in group
#  help                  Description of the interactive help system
#  ip                    Interface internet protocol config commands
#  ipv6                  IPv6 interface subcommands
#  isis                  Intermediate System - Intermediate System (IS-IS)
#  jumboframe            Jumboframe command
#  keepalive             Keep alive info
#  l2                    Layer 2 ping
#  l2protocol            Configure Layer2 Protocol
#  lacp                  LACP channel commands
#  lldp                  Link Layer Discovery Protocol
#  load-balance          Load balancing algorithm
#  load-interval         Specify interval for speed calculation of an interface
#  local-proxy-arp       Local Proxy ARP function for same interface
#  loopback              Enable loopback on current port
#  loopback-detect       Loopback Detect Function
#  mac                   Configure mac
#  macsec                MACsec information
#  mdi                   Set mdi to interface
#  media-type            Specifies the port media type
#  mka                   MACsec Key Agreement protocol
#  mlag                  Multi-Chassis Link Aggregation
#  mpls                  Configure MPLS specific attributes
#  mtu                   Set MTU value to interface
#  multi-link            Multi-link
#  mvr                   Enable/Disable MVR on the switch
#  mvr6                  Enable/Disable MVR6 on the switch
#  no                    Negate a command or set its defaults
#  ntp                   NTP configuration
#  optical-mode          config optical-mode
#  poe                   poe layer
#  port-block            Port block
#  port-isolate          Port isolate
#  port-xconnect         Port cross connect
#  proxy-arp             Proxy ARP function
#  ptp                   Precision Time Protocol (IEEE1588)
#  qos                   Quality of Service
#  quit                  Exit current mode and down to previous mode
#  rmon                  Remote Monitoring Protocol (RMON)
#  service-policy        Service policy
#  sflow                 Sampled flow
#  show                  Show running system information
#  shutdown              Shutdown the selected interface
#  smart-link            Smart Link
#  snmp                  Modify SNMP interface parameters
#  spanning-tree         Spanning-tree command
#  speed                 Set speed to interface
#  static-channel-group  Static channel commands
#  storm-control         Set the switching characteristics of layer2 interface
#  switchport            Set the mode of the Layer2 interface
#  trust                 Configure port trust state
#  tunnel                Tunnel info
#  udld                  UniDirectional Link Detectional
#  unicast               IPv4 and IPv6 unicast
#  unidirectional        unidirectional channel mode
#  vlan                  VLAN commands
#  voice                 Voice vlan
#  wavelength            config wavelength
