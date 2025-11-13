# Network Topology

```
Internet / ISP
      |
  [ Modem / ONT ]
      |
  (WAN - enp1s0, DHCP)
  [ DIY Router Appliance ]
  (LAN - enp2s0, 192.168.10.1/24)
      |
  [ Switch or Wi-Fi 6/6E AP ]
      |
  Wired clients / IoT / servers
```

1. The modem/ONT hands a public or ISP-managed address to the router WAN port (DHCP by default, but PPPoE or static can be modeled in `router-config.local.yml`).
2. The router’s LAN interface holds the `lan_gateway` (e.g., `192.168.10.1`) inside the `lan_cidr` (e.g., `192.168.10.0/24`).
3. dnsmasq advertises the LAN gateway as both the default route and DNS server while forwarding upstream queries to the `dns_servers` list from the config file.
4. Downstream switches/APs extend the LAN segment or map multiple VLANs back to the LAN interface via trunks; the provided playbook focuses on the primary LAN but can be extended.

Because nftables handles NAT and firewalling, all LAN segments can reach the WAN unless you tighten rules. The topology intentionally keeps Wi-Fi separate so the router focuses on routing, firewalling, and DHCP/DNS while APs manage radio duties.
