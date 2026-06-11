# Bridge Configuration

To use `br0`, you must configure your Artix Linux host's network to attach the physical interface to `br0`.

Example using `iproute2` temporarily:
```bash
ip link add name br0 type bridge
ip link set br0 up
ip link set eth0 master br0
```
*(Consult Artix documentation for persistent networking configuration with netifrc, NetworkManager, or systemd-networkd depending on your init).*
