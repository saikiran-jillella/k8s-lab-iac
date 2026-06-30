#!/bin/bash
set -e

source libvirt/vm-specs.env

for node in "${!CLUSTER_NODES[@]}"; do
    IP="${CLUSTER_NODES[$node]}"
    echo "Resetting $node ($IP)..."
    ssh -o StrictHostKeyChecking=no $CLUSTER_USER@$IP "echo "$CLUSTER_PASS" | sudo -S kubeadm reset -f 2>/dev/null" || true
    ssh -o StrictHostKeyChecking=no $CLUSTER_USER@$IP "echo "$CLUSTER_PASS" | sudo -S rm -rf /etc/cni/net.d 2>/dev/null" || true
    ssh -o StrictHostKeyChecking=no $CLUSTER_USER@$IP "echo "$CLUSTER_PASS" | sudo -S iptables -F 2>/dev/null && echo "$CLUSTER_PASS" | sudo -S iptables -t nat -F 2>/dev/null && echo "$CLUSTER_PASS" | sudo -S iptables -t mangle -F 2>/dev/null && echo "$CLUSTER_PASS" | sudo -S iptables -X 2>/dev/null" || true
done

echo "Cluster reset complete."
