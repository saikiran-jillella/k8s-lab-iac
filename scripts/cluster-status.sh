#!/bin/bash
set -e

echo "=== Cluster Nodes ==="
ssh -o StrictHostKeyChecking=no saikiran@192.168.0.109 "kubectl get nodes -o wide"

echo -e "\n=== Kube-VIP Status ==="
ssh -o StrictHostKeyChecking=no saikiran@192.168.0.109 "ip addr | grep 192.168.0.120" || echo "VIP 192.168.0.120 not found on cp1, it might be on another CP"

echo -e "\n=== Cilium Status ==="
ssh -o StrictHostKeyChecking=no saikiran@192.168.0.109 "cilium status"

echo -e "\n=== Container Runtime Health (cp1) ==="
ssh -o StrictHostKeyChecking=no saikiran@192.168.0.109 "sudo crictl ps"

echo -e "\n=== API Health ==="
ssh -o StrictHostKeyChecking=no saikiran@192.168.0.109 "kubectl cluster-info"
