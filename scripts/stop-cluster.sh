#!/bin/bash
set -euo pipefail

# Ensure execution context is always the project root
cd "$(dirname "$0")/.."

source libvirt/vm-specs.env
NODES=("${!CLUSTER_NODES[@]}")

for node in "${NODES[@]}"; do
    echo "[$node] Shutting down VM..."
    sudo virsh shutdown "$node" >/dev/null 2>&1 || true
done
