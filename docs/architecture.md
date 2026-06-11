# Architecture

This Kubernetes lab consists of 5 VMs running on KVM/QEMU:
- 3 Control Plane nodes (cp1, cp2, cp3)
- 2 Worker nodes (worker1, worker2)

## Components
- **OS**: Ubuntu 26.04 Cloud Image (Jammy/Noble/Future) via `cloud-init`.
- **Runtime**: containerd + crictl
- **CNI**: Cilium 1.19.4 with Native Routing and kube-proxy replacement.
- **Control Plane HA**: kube-vip configured as a static pod binding to 192.168.0.120.

All provisioning is driven by IaC without any manual configuration or `virt-manager` clicks.
