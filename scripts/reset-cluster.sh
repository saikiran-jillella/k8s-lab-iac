#!/bin/bash
set -e

NODES=("cp1" "cp2" "cp3" "worker1" "worker2")

for node in "${NODES[@]}"; do
    IP=""
    case $node in
        cp1) IP="192.168.0.109" ;;
        cp2) IP="192.168.0.111" ;;
        cp3) IP="192.168.0.113" ;;
        worker1) IP="192.168.0.110" ;;
        worker2) IP="192.168.0.112" ;;
    esac

    echo "Resetting $node ($IP)..."
    ssh -o StrictHostKeyChecking=no saikiran@$IP "sudo kubeadm reset -f" || true
    ssh -o StrictHostKeyChecking=no saikiran@$IP "sudo rm -rf /etc/cni/net.d" || true
    ssh -o StrictHostKeyChecking=no saikiran@$IP "sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X" || true
done

echo "Cluster reset complete."
