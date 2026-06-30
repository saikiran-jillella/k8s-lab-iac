#!/bin/bash
source libvirt/vm-specs.env

set -e

echo "=== Kubernetes Lab Addons Deployment ==="

# 1. Ensure we have the kubeconfig locally
mkdir -p "$HOME/.kube"
if [ ! -f "$HOME/.kube/config" ]; then
    echo "Pulling kubeconfig from cp1 (${CLUSTER_NODES[cp1]})..."
    scp -o StrictHostKeyChecking=no $CLUSTER_USER@${CLUSTER_NODES[cp1]}:~/.kube/config "$HOME/.kube/config" || {
        echo "Failed to pull kubeconfig. Is the cluster running?"
        exit 1
    }
    # Fix permissions
    chmod 600 "$HOME/.kube/config"
    # Ensure the server IP is pointing to the VIP instead of 127.0.0.1 if it was local to cp1
    # Actually, the kube-vip binds to $CLUSTER_VIP and the certs include it, so it should be correct.
else
    echo "Local ~/.kube/config already exists. Using it."
fi

# Ensure kubectl works
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "Error: kubectl cannot connect to the cluster. Please ensure the cluster is running and kubeconfig is valid."
    exit 1
fi

# 2. Install Metrics Server
echo "Deploying metrics-server..."
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ 2>/dev/null || true
helm repo update metrics-server
helm upgrade --install metrics-server metrics-server/metrics-server \
    --namespace kube-system \
    --set args={--kubelet-insecure-tls}

# 3. Install Kube-Prometheus-Stack
echo "Deploying kube-prometheus-stack..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update prometheus-community
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
    --namespace monitoring --create-namespace

echo "Addons deployment complete!"
echo "You can check the status of your monitoring stack by running:"
echo "  kubectl get pods -n monitoring"
