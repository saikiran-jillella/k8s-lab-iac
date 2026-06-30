# Networking

- **Subnet**: 192.168.0.0/24
- **Gateway**: 192.168.0.1
- **DNS**: 1.1.1.1, 8.8.8.8
- **Bridge**: `br0`

## Host Bridge vs. Libvirt NAT

This repository supports two primary networking modes for your VMs, defined by the `NETWORK_CONFIG` variable in `libvirt/vm-specs.env`.

### 1. Host Bridge (Default: `br0`)
By default, the lab expects a physical host bridge named `br0`. This connects the virtual machines directly to your local physical network (e.g., your home router's subnet), meaning the VMs get IPs from your router and are accessible from any device on your Wi-Fi/LAN.

> [!WARNING]
> **RISK OF NETWORK LOSS:** The automated scripts in this repository **DO NOT** configure the bridge on your host machine. Altering host networking is dangerous; a misconfigured bridge can immediately disconnect your host from the internet or drop your SSH session. 
> 
> If you choose the bridged route, you must manually create `br0` on your host *before* running any scripts. 

**Brief example for creating a bridge on Linux (via NetworkManager):**
```bash
# Example only. Ensure you understand these commands before running them!
nmcli connection add type bridge autoconnect yes con-name br0 ifname br0
nmcli connection modify br0 ipv4.method auto ipv6.method auto
# Attach your physical interface (e.g., eth0) to the bridge
nmcli connection add type bridge-slave autoconnect yes con-name bridge-slave-eth0 ifname eth0 master br0
```

### 2. Libvirt NAT (`network=default`)
If you want to avoid touching your host's physical network entirely, you can switch `NETWORK_CONFIG="network=default"` in `vm-specs.env`. This uses Libvirt's built-in isolated NAT network (usually `virbr0` on `192.168.122.0/24`).

> [!NOTE]
> If you use the NAT option, you **must** update the static IPs below to match your Libvirt DHCP scope (e.g., change `192.168.0.x` to `192.168.122.x`) in the `.env` file.

---

## Static IP Allocations
The following IPs are injected into the VMs at boot time via Cloud-Init templates:

- cp1: 192.168.0.109
- worker1: 192.168.0.110
- cp2: 192.168.0.111
- worker2: 192.168.0.112
- cp3: 192.168.0.113
- worker3: 192.168.0.114
- VIP: 192.168.0.120
