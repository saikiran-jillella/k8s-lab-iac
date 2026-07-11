#!/bin/bash
set -euo pipefail

# Ensure execution context is always the project root
cd "$(dirname "$0")/.."

source libvirt/vm-specs.env

# shellcheck source=scripts/lib/ssh-agent-setup.sh
source "$(dirname "$0")/lib/ssh-agent-setup.sh"

echo "=== Cluster Nodes ==="
ssh $SSH_OPTS $CLUSTER_USER@${CLUSTER_NODES[$PRIMARY_CP]} "kubectl get nodes -o wide"

echo -e "\n=== Kube-VIP Status ==="
ssh $SSH_OPTS $CLUSTER_USER@${CLUSTER_NODES[$PRIMARY_CP]} "ip addr | grep $CLUSTER_VIP" || echo "VIP $CLUSTER_VIP not found on $PRIMARY_CP, it might be on another CP"

echo -e "\n=== Cilium Status ==="
ssh $SSH_OPTS $CLUSTER_USER@${CLUSTER_NODES[$PRIMARY_CP]} "cilium status"

echo -e "\n=== Container Runtime Health ($PRIMARY_CP) ==="
ssh $SSH_OPTS $CLUSTER_USER@${CLUSTER_NODES[$PRIMARY_CP]} "echo \"$CLUSTER_PASS\" | sudo -S crictl ps 2>/dev/null"

echo -e "\n=== API Health ==="
ssh $SSH_OPTS $CLUSTER_USER@${CLUSTER_NODES[$PRIMARY_CP]} "kubectl cluster-info"
