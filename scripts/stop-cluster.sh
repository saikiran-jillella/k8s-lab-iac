#!/bin/bash
set -e

NODES=("cp1" "cp2" "cp3" "worker1" "worker2")

for node in "${NODES[@]}"; do
    echo "Shutting down $node..."
    sudo virsh shutdown "$node" || true
done
