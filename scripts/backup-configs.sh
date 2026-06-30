#!/bin/bash
source libvirt/vm-specs.env

set -e

BACKUP_DIR="backups/configs_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "Backing up IaC configs to $BACKUP_DIR..."
cp -r cloud-init kubeadm netplan scripts "$BACKUP_DIR/"
echo "Backup complete."
