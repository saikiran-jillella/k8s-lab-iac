#!/bin/bash
source libvirt/vm-specs.env

set -eo pipefail

echo "Starting Kubernetes Lab Provisioning..."

echo "Step 1: Creating VMs..."
./scripts/create-vms.sh

echo "Step 2: Setting up SSH Keys..."
./scripts/setup-ssh-keys.sh

echo "Step 3: Bootstrapping Cluster..."
./scripts/bootstrap-cluster.sh

echo "Step 4: Deploying Observability Addons..."
./scripts/deploy-addons.sh

echo "Kubernetes Lab is now fully provisioned, monitored, and ready!"
