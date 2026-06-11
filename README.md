# Kubernetes Home Lab - Infrastructure as Code

This repository contains the complete specification and automation scripts to provision a 5-node highly available Kubernetes cluster on KVM/QEMU using `libvirt`, `cloud-init`, and `kubeadm`.

## Prerequisites
- Host OS: Artix Linux
- KVM / QEMU / libvirt installed and running.
- `cloud-localds` utility installed (usually from `cloud-utils` package).
- A bridge network named `br0` configured on the host.

## Quick Start

1. Update your `~/.ssh/config`:
   ```sshconfig
   Host cp1
       HostName 192.168.0.109
       User saikiran

   Host worker1
       HostName 192.168.0.110
       User saikiran

   Host cp2
       HostName 192.168.0.111
       User saikiran

   Host worker2
       HostName 192.168.0.112
       User saikiran

   Host cp3
       HostName 192.168.0.113
       User saikiran
   ```

2. Create the virtual machines:
   ```bash
   ./scripts/create-vms.sh
   ```

3. Bootstrap the Kubernetes cluster:
   ```bash
   ./scripts/bootstrap-cluster.sh
   ```

4. Verify status:
   ```bash
   ./scripts/cluster-status.sh
   ```

## Documentation
- [Architecture](docs/architecture.md)
- [Networking](docs/networking.md)
- [Troubleshooting](docs/troubleshooting.md)
