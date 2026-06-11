#!/bin/bash
set -eo pipefail

IMAGE_URL="https://cloud-images.ubuntu.com/releases/26.04/release/ubuntu-26.04-server-cloudimg-amd64.img"
IMAGE_FILE="/var/lib/libvirt/images/ubuntu-26.04-server-cloudimg-amd64.img"
VM_DIR="/var/lib/libvirt/images"

# Nodes and resources
NODES=("cp1" "cp2" "cp3" "worker1" "worker2")
VCPUS=2
RAM=4096
DISK_SIZE="40G"
BRIDGE="br0"

if ! command -v cloud-localds &> /dev/null; then
    echo "cloud-localds could not be found. Please install cloud-utils or cloud-image-utils."
    exit 1
fi

if ! command -v virt-install &> /dev/null; then
    echo "virt-install could not be found."
    exit 1
fi

# Download image if it doesn't exist
if [ ! -f "$IMAGE_FILE" ]; then
    echo "Downloading Ubuntu 26.04 Cloud Image..."
    sudo wget -O "$IMAGE_FILE" "$IMAGE_URL"
fi

for node in "${NODES[@]}"; do
    echo "Provisioning $node..."
    
    DISK_PATH="$VM_DIR/$node.qcow2"
    SEED_PATH="$VM_DIR/$node-seed.iso"

    # Create the VM disk from the base image
    sudo cp "$IMAGE_FILE" "$DISK_PATH"
    sudo qemu-img resize "$DISK_PATH" $DISK_SIZE

    # Create the cloud-init seed ISO
    # We use user-data and network-config
    echo "Generating cloud-init seed for $node..."
    sudo cloud-localds --network-config netplan/$node.yaml "$SEED_PATH" cloud-init/$node.yaml

    # Create the VM using virt-install
    echo "Creating VM $node with virt-install..."
    sudo virt-install \
        --name "$node" \
        --memory $RAM \
        --vcpus $VCPUS \
        --disk path="$DISK_PATH",device=disk,bus=virtio,format=qcow2 \
        --disk path="$SEED_PATH",device=cdrom \
        --os-variant=ubuntu24.04 \
        --network bridge=$BRIDGE,model=virtio \
        --import \
        --noautoconsole \
        --graphics none

    echo "$node provisioned successfully."
done

echo "All VMs created and started. They will take a few minutes to boot and run cloud-init."
