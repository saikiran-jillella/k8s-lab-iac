#!/bin/bash
set -euo pipefail

# Ensure execution context is always the project root
cd "$(dirname "$0")/.."

source libvirt/vm-specs.env
NODES=("${!CLUSTER_NODES[@]}")
VM_DIR="/var/lib/libvirt/images"

for node in "${NODES[@]}"; do
    echo "Destroying and undefining $node..."
    sudo virsh destroy "$node" || true
    sudo virsh undefine "$node" --remove-all-storage || true
    sudo rm -f "$VM_DIR/$node-seed.iso" "$VM_DIR/$node.qcow2" || true
done

echo "All cluster VMs have been destroyed."
