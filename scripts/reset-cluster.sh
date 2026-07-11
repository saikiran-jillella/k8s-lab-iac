#!/bin/bash
set -euo pipefail

# Ensure execution context is always the project root
cd "$(dirname "$0")/.."

source libvirt/vm-specs.env

# shellcheck source=scripts/lib/ssh-agent-setup.sh
source "$(dirname "$0")/lib/ssh-agent-setup.sh"

for node in "${!CLUSTER_NODES[@]}"; do
    IP="${CLUSTER_NODES[$node]}"
    echo "[$node] Resetting Kubernetes node state..."
    ssh $SSH_OPTS $CLUSTER_USER@$IP "echo \"$CLUSTER_PASS\" | sudo -S kubeadm reset -f 2>/dev/null" | sed -u "s/^/[$node] /" || true
    ssh $SSH_OPTS $CLUSTER_USER@$IP "echo \"$CLUSTER_PASS\" | sudo -S rm -rf /etc/cni/net.d 2>/dev/null" || true
    ssh $SSH_OPTS $CLUSTER_USER@$IP "echo \"$CLUSTER_PASS\" | sudo -S iptables -F 2>/dev/null && echo \"$CLUSTER_PASS\" | sudo -S iptables -t nat -F 2>/dev/null && echo \"$CLUSTER_PASS\" | sudo -S iptables -t mangle -F 2>/dev/null && echo \"$CLUSTER_PASS\" | sudo -S iptables -X 2>/dev/null" || true
done

echo "Cluster reset complete."
