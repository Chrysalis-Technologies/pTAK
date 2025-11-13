# Hardware Bill of Materials

| Part | Qty | Approximate spec | Why it’s needed |
| --- | --- | --- | --- |
| Fanless 4×2.5 GbE mini router appliance | 1 | Intel N100, J4125, or similar 6–15 W CPU; 4× Intel i225/i226 2.5 GbE NICs; dual SO-DIMM slots; one M.2 NVMe or SATA bay | Core platform that provides enough NIC density for WAN, LAN, VLAN trunks, or out-of-band links while staying silent and low-power for 24/7 use. |
| DDR4/DDR5 SO-DIMM memory | 1 | 8–16 GB module (non-ECC is fine for homelab) | Ensures the router can run Debian/Ubuntu plus services like dnsmasq, collectors, or monitoring agents without swapping. |
| NVMe or SATA SSD | 1 | 256–512 GB, TLC flash preferred | Provides fast, reliable storage for the OS, logs, and any lightweight services; far more durable than microSD cards. |
| 12 V DC power adapter | 1 | 60–90 W brick that matches the appliance barrel connector | Supplies stable power; most appliances ship with one but verify wattage before deployment. |
| USB installer stick | 1 | 16 GB or larger USB 3.0 flash drive | Used to write the Debian/Ubuntu ISO and bootstrap the router before Ansible takes over. |
| Cat6/Cat6a patch cables | 2–6 | 0.3–1 m shielded or unshielded as needed | Connects WAN to modem/ONT and LAN ports to switches, APs, or lab gear; short cables minimize clutter near the router. |
| Wi-Fi 6/6E access point (optional) | 1 | PoE or DC-powered AP with multi-SSID/VLAN support | Keeps wireless duties off the router while still benefiting from the router’s policy enforcement and DHCP/DNS services. |
| Mounting / labeling kit (optional) | 1 | VESA/wall brackets, Velcro, zip ties, label tape | Lets you secure the appliance behind a monitor/rack and label each port/VLAN to avoid mistakes during maintenance. |

## Alternatives and Upgrades
- Swap to an Intel i3-N305/i5 low-power CPU box with 6–8 NICs if you need more VPN throughput or plan to run IDS tooling.
- Increase RAM to 32 GB and storage to 1 TB NVMe if you want to host lightweight containers or long-retention logs directly on the router.
- Choose appliances with integrated SFP+ or add a PCIe NIC for 10 GbE WAN/LAN if your upstream or core switch warrants it.
- Replace the bundled PSU with a redundant 12 V DC UPS or PoE-powered injector to ride through brownouts.

## What this DOESN’T include
This list assumes you already have an upstream modem or ONT, any necessary ISP-supplied credentials, and downstream switching/AP infrastructure. It also skips rack shelves, PDUs, and professional crimp tools; bring those if your deployment requires them.
