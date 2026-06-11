# Recovery Guide

If a node fails:
1. Run `./scripts/destroy-vms.sh` to completely wipe the cluster.
2. Rerun `./scripts/create-vms.sh` and `./scripts/bootstrap-cluster.sh` to recreate.

Alternatively, to reset kubernetes without destroying VMs:
1. Run `./scripts/reset-cluster.sh`
2. Rerun `./scripts/bootstrap-cluster.sh`
