#!/bin/bash
set -euo pipefail

# Ensure execution context is always the project root
cd "$(dirname "$0")/.."

source libvirt/vm-specs.env
NODES=("${!CLUSTER_NODES[@]}")

# shellcheck source=scripts/lib/ssh-agent-setup.sh
source "$(dirname "$0")/lib/ssh-agent-setup.sh"

for node in "${NODES[@]}"; do
    echo "Starting $node..."
    sudo virsh start "$node" 2>/dev/null || true
done

echo "Waiting for control plane to boot..."
echo "Waiting for $PRIMARY_CP to boot and SSH to become available (max 3 minutes)..."
MAX_RETRIES=36
count=0
    until ssh $SSH_OPTS $CLUSTER_USER@${CLUSTER_NODES[$PRIMARY_CP]} "echo '$PRIMARY_CP is up'"; do
        sleep 5
        count=$((count+1))
        if (( count >= MAX_RETRIES )); then
            echo "Error: Timed out waiting for $PRIMARY_CP! Do the VMs exist?"
            exit 1
        fi
    done

echo "Cluster is awake! Fetching node status:"
ssh $SSH_OPTS $CLUSTER_USER@${CLUSTER_NODES[$PRIMARY_CP]} "kubectl get nodes"
