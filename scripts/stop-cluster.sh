#!/bin/bash
set -euo pipefail

# Ensure execution context is always the project root
cd "$(dirname "$0")/.."

source libvirt/vm-specs.env
NODES=("${!CLUSTER_NODES[@]}")

for node in "${NODES[@]}"; do
    echo "Shutting down $node..."
    sudo virsh shutdown "$node" || true
done
