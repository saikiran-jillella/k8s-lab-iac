#!/bin/bash
source libvirt/vm-specs.env

set -e

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
