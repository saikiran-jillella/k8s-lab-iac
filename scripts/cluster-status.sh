#!/bin/bash
set -euo pipefail

# Ensure execution context is always the project root
cd "$(dirname "$0")/.."

source libvirt/vm-specs.env

# shellcheck source=scripts/lib/ssh-agent-setup.sh
source "$(dirname "$0")/lib/ssh-agent-setup.sh"

echo "=== Cluster Nodes ==="
ssh -o StrictHostKeyChecking=no $CLUSTER_USER@${CLUSTER_NODES[cp1]} "kubectl get nodes -o wide"

echo -e "\n=== Kube-VIP Status ==="
ssh -o StrictHostKeyChecking=no $CLUSTER_USER@${CLUSTER_NODES[cp1]} "ip addr | grep $CLUSTER_VIP" || echo "VIP $CLUSTER_VIP not found on cp1, it might be on another CP"

echo -e "\n=== Cilium Status ==="
ssh -o StrictHostKeyChecking=no $CLUSTER_USER@${CLUSTER_NODES[cp1]} "cilium status"

echo -e "\n=== Container Runtime Health (cp1) ==="
ssh -o StrictHostKeyChecking=no $CLUSTER_USER@${CLUSTER_NODES[cp1]} "echo "$CLUSTER_PASS" | sudo -S crictl ps 2>/dev/null"

echo -e "\n=== API Health ==="
ssh -o StrictHostKeyChecking=no $CLUSTER_USER@${CLUSTER_NODES[cp1]} "kubectl cluster-info"
