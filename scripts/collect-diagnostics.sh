#!/bin/bash
set -euo pipefail

# Ensure execution context is always the project root
cd "$(dirname "$0")/.."

source libvirt/vm-specs.env
NODES=("${!CLUSTER_NODES[@]}")

# shellcheck source=scripts/lib/ssh-agent-setup.sh
source "$(dirname "$0")/lib/ssh-agent-setup.sh"

BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "Collecting virsh dumpxml..."
for node in "${NODES[@]}"; do
    sudo virsh dumpxml "$node" > "$BACKUP_DIR/$node.xml" || true
done

echo "Collecting network info from $PRIMARY_CP..."
ssh $SSH_OPTS $CLUSTER_USER@${CLUSTER_NODES[$PRIMARY_CP]} "ip addr" > "$BACKUP_DIR/${PRIMARY_CP}_ip_addr.txt"
ssh $SSH_OPTS $CLUSTER_USER@${CLUSTER_NODES[$PRIMARY_CP]} "ip route" > "$BACKUP_DIR/${PRIMARY_CP}_ip_route.txt"

echo "Collecting cluster info..."
ssh $SSH_OPTS $CLUSTER_USER@${CLUSTER_NODES[$PRIMARY_CP]} "kubectl version" > "$BACKUP_DIR/kubectl_version.txt" || true
ssh $SSH_OPTS $CLUSTER_USER@${CLUSTER_NODES[$PRIMARY_CP]} "kubectl get nodes -o wide" > "$BACKUP_DIR/kubectl_nodes.txt" || true
ssh $SSH_OPTS $CLUSTER_USER@${CLUSTER_NODES[$PRIMARY_CP]} "cilium status" > "$BACKUP_DIR/cilium_status.txt" || true
ssh $SSH_OPTS $CLUSTER_USER@${CLUSTER_NODES[$PRIMARY_CP]} "echo \"$CLUSTER_PASS\" | sudo -S crictl version 2>/dev/null" > "$BACKUP_DIR/crictl_version.txt" || true
ssh $SSH_OPTS $CLUSTER_USER@${CLUSTER_NODES[$PRIMARY_CP]} "echo \"$CLUSTER_PASS\" | sudo -S kubeadm version 2>/dev/null" > "$BACKUP_DIR/kubeadm_version.txt" || true
ssh $SSH_OPTS $CLUSTER_USER@${CLUSTER_NODES[$PRIMARY_CP]} "containerd --version" > "$BACKUP_DIR/containerd_version.txt" || true

echo "Diagnostics collected in $BACKUP_DIR"
