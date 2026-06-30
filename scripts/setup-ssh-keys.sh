#!/bin/bash
set -e

source libvirt/vm-specs.env
# CLUSTER_NODES associative array is now provided by the central config

echo "=== Kubernetes Lab SSH Key Setup ==="
echo "This script will push your SSH public key to all cluster nodes."

# Prompt for the key to use
DEFAULT_KEY="$HOME/.ssh/id_ed25519.pub"
read -p "Enter path to your public SSH key [$DEFAULT_KEY]: " PUB_KEY

if [ -z "$PUB_KEY" ]; then
    PUB_KEY="$DEFAULT_KEY"
fi

if [ ! -f "$PUB_KEY" ]; then
    echo "Error: Public key not found at $PUB_KEY"
    exit 1
fi

echo "Using key: $PUB_KEY"
echo "You may be prompted for the node password ('$CLUSTER_PASS') multiple times."

for node in "${!CLUSTER_NODES[@]}"; do
    IP="${CLUSTER_NODES[$node]}"
    echo "Pushing key to $node ($IP)..."
    ssh-keygen -R "$IP" 2>/dev/null || true
    ssh-keygen -R "$node" 2>/dev/null || true
    ssh-copy-id -i "$PUB_KEY" -o StrictHostKeyChecking=no $CLUSTER_USER@$IP || true
done

echo "SSH key setup complete!"
