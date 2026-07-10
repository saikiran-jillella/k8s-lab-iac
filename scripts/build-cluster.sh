#!/bin/bash
set -u

# Ensure execution context is always the project root
cd "$(dirname "$0")/.."

source libvirt/vm-specs.env



# shellcheck source=scripts/lib/ssh-agent-setup.sh
source "$(dirname "$0")/lib/ssh-agent-setup.sh"

echo "Starting Kubernetes Lab Provisioning..."

echo "Step 1: Creating VMs..."
./scripts/create-vms.sh || { echo "FAILED at Step 1: create-vms.sh"; exit 1; }

echo "Step 2: Setting up SSH Keys..."
./scripts/setup-ssh-keys.sh || { echo "FAILED at Step 2: setup-ssh-keys.sh"; exit 1; }

echo "Step 3: Bootstrapping Cluster..."
./scripts/bootstrap-cluster.sh || { echo "FAILED at Step 3: bootstrap-cluster.sh"; exit 1; }

echo "Step 4: Deploying Observability Addons..."
./scripts/deploy-addons.sh || { echo "FAILED at Step 4: deploy-addons.sh"; exit 1; }

echo "Kubernetes Lab is now fully provisioned, monitored, and ready!"
