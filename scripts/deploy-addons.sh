#!/bin/bash
set -euo pipefail

# Ensure execution context is always the project root
cd "$(dirname "$0")/.."

source libvirt/vm-specs.env


# shellcheck source=scripts/lib/ssh-agent-setup.sh
source "$(dirname "$0")/lib/ssh-agent-setup.sh"

echo "=== Kubernetes Lab Addons Deployment ==="

# Ensure kubectl is installed locally so we can manage the cluster
if ! command -v kubectl &> /dev/null; then
    echo "kubectl not found on host. Installing the latest version..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
fi

# Ensure helm is installed locally so we can deploy addons
if ! command -v helm &> /dev/null; then
    echo "helm not found on host. Installing the latest version..."
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
    rm get_helm.sh
fi


# 1. Always pull a fresh kubeconfig from cp1 (cluster may have been rebuilt)
mkdir -p "$HOME/.kube"
echo "Pulling kubeconfig from cp1 (${CLUSTER_NODES[cp1]})..."
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $CLUSTER_USER@${CLUSTER_NODES[cp1]}:~/.kube/config "$HOME/.kube/config" || {
    echo "Failed to pull kubeconfig. Is the cluster running?"
    exit 1
}
chmod 600 "$HOME/.kube/config"

# Ensure kubectl works
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "Error: kubectl cannot connect to the cluster. Please ensure the cluster is running and kubeconfig is valid."
    exit 1
fi

# 2. Install Metrics Server
echo "Deploying metrics-server (streaming live cluster events)..."
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ 2>/dev/null || true
helm repo update metrics-server >/dev/null 2>&1

helm upgrade --install metrics-server metrics-server/metrics-server \
    --namespace kube-system \
    --timeout 15m \
    --set args={--kubelet-insecure-tls} > /tmp/helm-metrics.log 2>&1 &
HELM_PID=$!
sleep 2
kubectl get events -n kube-system --watch &
EVENTS_PID=$!
wait $HELM_PID
HELM_EXIT=$?
kill $EVENTS_PID 2>/dev/null || true
if [ $HELM_EXIT -ne 0 ]; then
    echo -e "\nError deploying metrics-server! Logs:"
    cat /tmp/helm-metrics.log
    exit 1
fi
echo -e "\nMetrics-server deployed successfully!\n"

# 3. Install Kube-Prometheus-Stack
echo "Deploying kube-prometheus-stack (streaming live cluster events)..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update prometheus-community >/dev/null 2>&1

helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
    --namespace monitoring --create-namespace \
    --timeout 15m > /tmp/helm-prometheus.log 2>&1 &
HELM_PID=$!
sleep 2
kubectl get events -n monitoring --watch &
EVENTS_PID=$!
wait $HELM_PID
HELM_EXIT=$?
kill $EVENTS_PID 2>/dev/null || true
if [ $HELM_EXIT -ne 0 ]; then
    echo -e "\nError deploying kube-prometheus-stack! Logs:"
    cat /tmp/helm-prometheus.log
    exit 1
fi

echo "Addons deployment complete!"
echo "You can check the status of your monitoring stack by running:"
echo "  kubectl get pods -n monitoring"
