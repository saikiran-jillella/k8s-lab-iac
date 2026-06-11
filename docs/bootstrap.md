# Bootstrap Guide

1. Review and prepare host SSH config `~/.ssh/config` to resolve hostnames.
2. Ensure `br0` exists on your host.
3. Run `./scripts/create-vms.sh` to download the image, create seed ISOs, and boot the VMs.
4. Run `./scripts/bootstrap-cluster.sh` to initialize Kubernetes and join all nodes.
