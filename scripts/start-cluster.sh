#!/bin/bash
set -e

source libvirt/vm-specs.env
NODES=("${!CLUSTER_NODES[@]}")

for node in "${NODES[@]}"; do
    echo "Starting $node..."
    sudo virsh start "$node" 2>/dev/null || true
done

echo "Waiting for control plane to boot..."
until ssh -o StrictHostKeyChecking=no $CLUSTER_USER@${CLUSTER_NODES[cp1]} "echo 'cp1 is up'" 2>/dev/null; do
    sleep 2
done

echo "Cluster is awake! Fetching node status:"
ssh -o StrictHostKeyChecking=no $CLUSTER_USER@${CLUSTER_NODES[cp1]} "kubectl get nodes"
