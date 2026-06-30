#!/bin/bash
set -e

source libvirt/vm-specs.env
NODES=("${!CLUSTER_NODES[@]}")
VM_DIR="/var/lib/libvirt/images"

for node in "${NODES[@]}"; do
    echo "Destroying and undefining $node..."
    sudo virsh destroy "$node" || true
    sudo virsh undefine "$node" --remove-all-storage || true
    sudo rm -f "$VM_DIR/$node-seed.iso" || true
done

echo "All cluster VMs have been destroyed."
