#!/bin/bash
set -e

BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "Collecting virsh dumpxml..."
for node in cp1 cp2 cp3 worker1 worker2; do
    sudo virsh dumpxml "$node" > "$BACKUP_DIR/$node.xml" || true
done

echo "Collecting network info from cp1..."
ssh -o StrictHostKeyChecking=no saikiran@192.168.0.109 "ip addr" > "$BACKUP_DIR/cp1_ip_addr.txt"
ssh -o StrictHostKeyChecking=no saikiran@192.168.0.109 "ip route" > "$BACKUP_DIR/cp1_ip_route.txt"

echo "Collecting cluster info..."
ssh -o StrictHostKeyChecking=no saikiran@192.168.0.109 "kubectl version" > "$BACKUP_DIR/kubectl_version.txt" || true
ssh -o StrictHostKeyChecking=no saikiran@192.168.0.109 "kubectl get nodes -o wide" > "$BACKUP_DIR/kubectl_nodes.txt" || true
ssh -o StrictHostKeyChecking=no saikiran@192.168.0.109 "cilium status" > "$BACKUP_DIR/cilium_status.txt" || true
ssh -o StrictHostKeyChecking=no saikiran@192.168.0.109 "sudo crictl version" > "$BACKUP_DIR/crictl_version.txt" || true
ssh -o StrictHostKeyChecking=no saikiran@192.168.0.109 "sudo kubeadm version" > "$BACKUP_DIR/kubeadm_version.txt" || true
ssh -o StrictHostKeyChecking=no saikiran@192.168.0.109 "containerd --version" > "$BACKUP_DIR/containerd_version.txt" || true

echo "Diagnostics collected in $BACKUP_DIR"
