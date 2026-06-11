# Networking

- **Subnet**: 192.168.0.0/24
- **Gateway**: 192.168.0.1
- **DNS**: 1.1.1.1, 8.8.8.8
- **Bridge**: `br0`

## IPs
- cp1: 192.168.0.109
- worker1: 192.168.0.110
- cp2: 192.168.0.111
- worker2: 192.168.0.112
- cp3: 192.168.0.113
- VIP: 192.168.0.120

Static IPs are assigned via `netplan` integrated into `cloud-init`.
