# Networking

- **Subnet**: Isolated mode: `192.168.122.0/24` (default) · Bridged mode: your home LAN (e.g. `192.168.0.0/24`)
- **Gateway**: Auto-detected from host (`virbr0` for isolated, `br0` for bridged)
- **DNS**: 1.1.1.1, 8.8.8.8

## Host Bridge vs. Libvirt NAT

This repository supports two networking modes, selected by `NETWORK_MODE` in `libvirt/vm-specs.env`.

### 1. Libvirt NAT (`isolated`) — Default
`NETWORK_MODE="isolated"` connects the VMs to Libvirt's internal, isolated virtual switch (`virbr0`). Your host machine acts as the NAT router to the outside world.
*   **Use Case:** Isolated sandbox (e.g., testing inside a VM), or you don't want to touch physical bridge networking.
*   **Requirement:** The libvirt default network must be active (it usually is by default).

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

### 2. Host Bridge (`bridged`) — Optional
`NETWORK_MODE="bridged"` connects the VMs directly to your physical home router via a host bridge (`br0`). VMs become first-class citizens on your physical LAN.

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

---

## Static IP Allocations
The following IPs are injected into the VMs at boot time via Cloud-Init templates.
The actual prefix depends on your chosen `NETWORK_MODE`:
- **Isolated (default):** `192.168.122.x` (derived from `virbr0`)
- **Bridged:** Your home LAN prefix (derived from `br0`)

| Node | Isolated IP | Last Octet |
|------|-------------|------------|
| cp1 | 192.168.122.109 | .109 |
| cp2 | 192.168.122.110 | .110 |
| cp3 | 192.168.122.111 | .111 |
| worker1 | 192.168.122.112 | .112 |
| worker2 | 192.168.122.113 | .113 |
| worker3 | 192.168.122.114 | .114 |
| VIP (kube-vip) | 192.168.122.120 | .120 |
