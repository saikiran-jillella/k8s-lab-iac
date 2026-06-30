#!/bin/bash
set -e

source libvirt/vm-specs.env
NODES=("${!CLUSTER_NODES[@]}")

for node in "${NODES[@]}"; do
    echo "Shutting down $node..."
    sudo virsh shutdown "$node" || true
done
