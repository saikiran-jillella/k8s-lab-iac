#!/bin/bash
set -euo pipefail

# Ensure execution context is always the project root
cd "$(dirname "$0")/.."

source libvirt/vm-specs.env
# CLUSTER_NODES associative array is now provided by the central config

echo "=== Kubernetes Lab SSH Key Setup ==="
echo "This script will push your SSH public key to all cluster nodes."

# shellcheck source=scripts/lib/ssh-agent-setup.sh
source "$(dirname "$0")/lib/ssh-agent-setup.sh"

PUB_KEY="$LAB_KEY.pub"

echo "Using key: $PUB_KEY"
echo "You may be prompted for the node password ('$CLUSTER_PASS') multiple times."

echo "Ensuring all nodes are powered on (Parallel Auto-Wake)..."
for node in "${!CLUSTER_NODES[@]}"; do
    sudo virsh start "$node" 2>/dev/null || true
done

for node in "${!CLUSTER_NODES[@]}"; do
    IP="${CLUSTER_NODES[$node]}"

    echo "[$node] Waiting for VM ($IP) to boot and SSH to become available (max 3 minutes)..."

    MAX_RETRIES=36
    count=0

    until sshpass -p "$CLUSTER_PASS" ssh \
        -o ConnectTimeout=5 \
        -o UserKnownHostsFile=/dev/null \
        -o StrictHostKeyChecking=no \
        "$CLUSTER_USER@$IP" \
        "echo ready" >/dev/null 2>&1
    do
        sleep 5
        count=$((count + 1))

        if (( count >= MAX_RETRIES )); then
            echo "[$node] Error: Timed out! The VM might not exist or is failing to boot."
            exit 1
        fi
    done

    echo "[$node] Pushing SSH key..."

    ssh-keygen -R "$IP" >/dev/null 2>&1 || true
    ssh-keygen -R "$node" >/dev/null 2>&1 || true

    sshpass -p "$CLUSTER_PASS" ssh-copy-id \
        -i "$PUB_KEY" \
        -o StrictHostKeyChecking=no \
        "$CLUSTER_USER@$IP" >/dev/null 2>&1 || true

    echo "[$node] Key successfully installed."
    echo ""
done

echo "SSH key setup complete!"