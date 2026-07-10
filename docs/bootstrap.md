# Bootstrap Guide

1. Review `libvirt/vm-specs.env` and adjust `NETWORK_MODE`, node hardware, and IPs as needed.
2. Ensure a dedicated SSH key for this lab exists (`~/.ssh/k8s_lab_ed25519`). Generate one if not: `ssh-keygen -t ed25519 -N "" -f ~/.ssh/k8s_lab_ed25519`
3. If using `NETWORK_MODE="bridged"`, ensure `br0` exists on your host before proceeding (see `docs/networking.md`).
4. Run `./scripts/build-cluster.sh` to provision VMs, bootstrap Kubernetes, and deploy addons in one shot.

Or run phases individually:
```bash
./scripts/create-vms.sh        # Download image, create VMs
./scripts/setup-ssh-keys.sh    # Push SSH keys to VMs
./scripts/bootstrap-cluster.sh # Init Kubernetes + join nodes
./scripts/deploy-addons.sh     # Deploy Prometheus stack
```
