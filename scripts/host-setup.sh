#!/bin/bash
set -euo pipefail

# Ensure execution context is always the project root
cd "$(dirname "$0")/.."

source libvirt/vm-specs.env


echo "=== Kubernetes Lab Host Setup ==="
echo "This script will install KVM/libvirt dependencies and configure your host."

# 1. OS Detection & Package Installation
if command -v pacman >/dev/null 2>&1; then
    echo "Detected Arch/Artix Linux. Installing packages..."
    sudo pacman -S --needed qemu-full qemu-img qemu-system-x86 libvirt virt-manager dnsmasq iptables-nft edk2-ovmf virt-install guestfs-tools virtiofsd kubectl helm
elif command -v apt-get >/dev/null 2>&1; then
    echo "Detected Debian/Ubuntu. Installing packages..."
    sudo apt-get update
    sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst virt-manager dnsmasq iptables kubectl helm
elif command -v dnf >/dev/null 2>&1; then
    echo "Detected RHEL/Fedora. Installing packages..."
    sudo dnf install -y @virtualization dnsmasq iptables kubectl helm
else
    echo "Warning: Unsupported package manager. Please install qemu, libvirt, kubectl, and helm manually."
fi

# 2. User Groups
echo "Adding user $USER to libvirt and kvm groups..."
sudo usermod -aG libvirt "$USER" 2>/dev/null || true
sudo usermod -aG kvm "$USER" 2>/dev/null || true

# 3. Network Routing Configuration
echo "Configuring sysctl for libvirt networking..."
echo "net.ipv4.ip_forward = 1" | sudo tee /etc/sysctl.d/99-libvirt.conf > /dev/null
sudo sysctl -p /etc/sysctl.d/99-libvirt.conf 2>/dev/null || true

# 4. Dynamic Init System Detection & Service Enablement
INIT_COMM=$(ps -p 1 -o comm=)
echo "Detected init system: $INIT_COMM"

case "$INIT_COMM" in
    systemd)
        echo "Enabling and starting libvirtd via systemd..."
        sudo systemctl enable --now libvirtd
        ;;
    dinit)
        echo "Enabling and starting libvirtd via dinit..."
        if [ -d /etc/dinit.d ]; then
            sudo ln -sf /etc/dinit.d/libvirtd /etc/dinit.d/boot.d/ 2>/dev/null || true
            sudo dinitctl start libvirtd || true
        else
            echo "dinit directory not found. Please start libvirtd manually."
        fi
        ;;
    init)
        if command -v rc-update >/dev/null 2>&1; then
            echo "Enabling and starting libvirtd via openrc..."
            sudo rc-update add libvirtd default
            sudo rc-service libvirtd start
        else
            echo "Unknown init variant. Please start libvirtd manually."
        fi
        ;;
    *)
        echo "Unsupported init system ($INIT_COMM). Please enable and start libvirtd manually."
        ;;
esac

echo "Host setup complete!"
echo "NOTE: You may need to log out and log back in for group changes to take effect."
