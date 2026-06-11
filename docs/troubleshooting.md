# Troubleshooting Guide

1. Check if VMs are running:
   ```bash
   sudo virsh list --all
   ```

2. Check node health:
   ```bash
   ./scripts/cluster-status.sh
   ```

3. Collect diagnostics:
   ```bash
   ./scripts/collect-diagnostics.sh
   ```
   This will capture node state, libvirt definitions, and networking info.

4. If CNI (Cilium) fails:
   ```bash
   cilium status
   kubectl -n kube-system logs -l k8s-app=cilium
   ```
