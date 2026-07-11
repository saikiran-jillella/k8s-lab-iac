#!/bin/bash
set -euo pipefail

# Ensure execution context is always the project root
cd "$(dirname "$0")/.."

source libvirt/vm-specs.env

# Helper function to convert human-readable sizes to raw MiB for virt-install
normalize_ram_to_mib() {
    local input=$1
    input=${input^^} # Convert to uppercase
    local val=${input//[!0-9]/} # Extract numbers
    
    if [[ $input == *GIB ]] || [[ $input == *G ]]; then
        echo $(( val * 1024 ))
    elif [[ $input == *GB ]]; then
        # 1 GB = 1000^3 bytes, output needs to be in MiB (1024^2 bytes)
        echo $(( (val * 1000000000) / 1048576 ))
    elif [[ $input == *MIB ]] || [[ $input == *M ]]; then
        echo $val
    elif [[ $input == *MB ]]; then
        # 1 MB = 1000^2 bytes
        local mib=$(( (val * 1000000) / 1048576 ))
        echo $(( mib > 0 ? mib : 1 )) # Prevent 0 MiB allocation
    else
        echo "$input" # Assume it's already a raw number in MiB
    fi
}

# Helper function to convert human-readable sizes to raw bytes for qemu-img
normalize_disk_size() {
    local input=$1
    input=${input^^} # Convert to uppercase
    local val=${input//[!0-9]/} # Extract numbers
    
    if [[ $input == *GIB ]] || [[ $input == *G ]]; then
        echo $(( val * 1073741824 )) # 1024^3
    elif [[ $input == *GB ]]; then
        echo $(( val * 1000000000 )) # 1000^3
    elif [[ $input == *MIB ]] || [[ $input == *M ]]; then
        echo $(( val * 1048576 ))    # 1024^2
    elif [[ $input == *MB ]]; then
        echo $(( val * 1000000 ))    # 1000^2
    else
        # If no suffix is provided (e.g., just '40'), assume GiB for backward compatibility
        echo $(( val * 1073741824 ))
    fi
}

IMAGE_FILE="/var/lib/libvirt/images/ubuntu-26.04-server-cloudimg-amd64.img"
VM_DIR="/var/lib/libvirt/images"

# Extract node names from associative array
NODES=("${!CLUSTER_NODES[@]}")

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
    echo "[$node] Provisioning..."
    
    DISK_PATH="$VM_DIR/$node.qcow2"
    SEED_PATH="$VM_DIR/$node-seed.iso"

    if [ -f "$DISK_PATH" ]; then
        echo "VM $node already exists at $DISK_PATH. Skipping..."
        echo "WARNING: If you changed configuration in vm-specs.env for $node, you MUST run destroy-vms.sh first!"
        continue
    fi
    
    # Determine Role Defaults based on node prefix
    if [[ "$node" == cp* ]]; then
        ROLE_VCPU=${CP_VCPUS:-2}
        ROLE_RAM=${CP_RAM:-2048}
        ROLE_DISK=${CP_DISK:-"20G"}
    elif [[ "$node" == worker* ]]; then
        ROLE_VCPU=${WORKER_VCPUS:-4}
        ROLE_RAM=${WORKER_RAM:-4096}
        ROLE_DISK=${WORKER_DISK:-"40G"}
    else
        # Safety fallback
        ROLE_VCPU=2
        ROLE_RAM=2048
        ROLE_DISK="20G"
    fi

    # Resolve per-node overrides or fall back to role defaults
    NODE_VCPU=${NODE_VCPUS[$node]:-$ROLE_VCPU}
    NODE_RAM_SIZE=$(normalize_ram_to_mib "${NODE_RAM[$node]:-$ROLE_RAM}")
    NODE_DISK_SIZE=$(normalize_disk_size "${NODE_DISK[$node]:-$ROLE_DISK}")
    NODE_IP=${CLUSTER_NODES[$node]}

    # Create the VM disk from the base image
    echo "[$node] Preparing disk image ($NODE_DISK_SIZE)..."
    sudo cp "$IMAGE_FILE" "$DISK_PATH"
    sudo qemu-img resize "$DISK_PATH" "$NODE_DISK_SIZE" >/dev/null 2>&1

    # Generate Node-Specific Configs from Templates
    mkdir -p .generated
    
    # Inject Credentials and Hostname into Cloud-Init
    sed -e "s/{{HOSTNAME}}/$node/g" \
        -e "s/{{CLUSTER_USER}}/${CLUSTER_USER:-k8sadmin}/g" \
        -e "s/{{CLUSTER_PASS}}/${CLUSTER_PASS:-k8sadmin}/g" \
        -e "s/{{GITHUB_SSH_USER}}/${GITHUB_SSH_USER:-}/g" \
        templates/cloud-init.yaml.template > .generated/cloud-init-$node.yaml
        
    # Inject IP and Routing into Netplan
    sed -e "s/{{IP_ADDRESS}}/$NODE_IP/g" \
        -e "s/{{CIDR_SUFFIX}}/${CIDR_SUFFIX:-24}/g" \
        -e "s/{{GATEWAY_IP}}/${GATEWAY_IP:-192.168.0.1}/g" \
        -e "s/{{NAMESERVERS}}/${NAMESERVERS:-1.1.1.1, 8.8.8.8}/g" \
        templates/netplan.yaml.template > .generated/netplan-$node.yaml

    # Generate Kubernetes manifests if this is the primary control plane
    if [[ "$node" == "$PRIMARY_CP" ]]; then
        sed -e "s/{{CP1_IP}}/$NODE_IP/g" \
            -e "s/{{CLUSTER_VIP}}/${CLUSTER_VIP:-$CLUSTER_VIP}/g" \
            -e "s/{{PRIMARY_CP}}/$PRIMARY_CP/g" \
            templates/kubeadm-init.yaml.template > .generated/kubeadm-init.yaml
        sed -e "s/{{CLUSTER_VIP}}/${CLUSTER_VIP:-$CLUSTER_VIP}/g" \
            templates/kube-vip.yaml.template > .generated/kube-vip.yaml
        sed -e "s/{{CLUSTER_VIP}}/${CLUSTER_VIP:-$CLUSTER_VIP}/g" \
            templates/cilium-values.yaml.template > .generated/cilium-values.yaml
    fi

    # Create the cloud-init seed ISO
    echo "[$node] Generating cloud-init seed..."
    sudo cloud-localds --network-config .generated/netplan-$node.yaml "$SEED_PATH" .generated/cloud-init-$node.yaml

    # Create the VM using virt-install
    echo "[$node] Creating VM with virt-install (VCPUS: $NODE_VCPU, RAM: ${NODE_RAM_SIZE}MB, Disk: $NODE_DISK_SIZE)..."
    sudo virt-install \
        --quiet \
        --name "$node" \
        --memory "$NODE_RAM_SIZE" \
        --vcpus "$NODE_VCPU" \
        --disk path="$DISK_PATH",device=disk,bus=virtio,format=qcow2 \
        --disk path="$SEED_PATH",device=cdrom \
        --os-variant="$OS_VARIANT" \
        --network "${NETWORK_CONFIG}",model=virtio \
        --import \
        --noautoconsole \
        --autostart \
        --graphics none

    echo "[$node] Provisioned successfully."
    echo ""
done

echo "All VMs created and started. Because we used the golden image, they will be ready in seconds."
