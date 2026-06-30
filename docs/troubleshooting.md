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

5. Inspecting failing Pods:
   If a pod is stuck in `CrashLoopBackOff` or `Pending`, get detailed events:
   ```bash
   kubectl describe pod <pod-name> -n <namespace>
   ```
   To view the application logs:
   ```bash
   kubectl logs <pod-name> -n <namespace>
   ```

6. Inspecting Host Services (Kubelet or Containerd):
   If a node is `NotReady`, SSH into the node and check the system logs:
   ```bash
   ssh $CLUSTER_USER@${CLUSTER_NODES[worker1]}
   sudo journalctl -u kubelet -f
   sudo journalctl -u containerd -f
   ```
