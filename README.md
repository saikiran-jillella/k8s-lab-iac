<div align="center">
  <h1>Kubernetes Home Lab IaC</h1>
  <p><i>A fully automated 6-node KVM Kubernetes cluster from scratch.</i></p>

  ![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.36-blue?logo=kubernetes)
  ![Cilium](https://img.shields.io/badge/Cilium-v1.19.4-yellow?logo=cilium)
  ![Ubuntu](https://img.shields.io/badge/Ubuntu-26.04-E95420?logo=ubuntu)
</div>

---

This repository contains the Infrastructure-as-Code (IaC) used to provision a personal 6-node Kubernetes home lab on bare-metal Linux. It relies on **KVM/QEMU**, **Cloud-Init**, and **Kubeadm** to build a reproducible cluster environment.

## Overview
- **Topology**: 3 Control Planes & 3 Worker Nodes.
- **Networking**: Configured with [Cilium CNI](https://cilium.io/) and [Kube-VIP](https://kube-vip.io/).
- **Configuration**: The entire cluster scales dynamically from a single configuration file.
- **Automation**: Scripts handle everything from bare-metal dependencies to Helm observability charts.

---

## Hardware & Configuration

Linux handles CPU time-slicing (oversubscription) well, meaning a 1-to-1 mapping of physical cores to vCPUs is not strictly required. This specific lab topology runs comfortably on a standard 8-core machine. 

By default, the cluster is configured asymmetrically in `libvirt/vm-specs.env`:
*   **CPU:** 18 vCPUs total (Control planes use 2 vCPUs, workers use 4 vCPUs).
*   **RAM:** 18G total (Control planes use 2G, workers use 4G).
*   **Storage:** 180G total (Control planes use 20G, workers use 40G).
*   **Network:** Defaults to Libvirt's isolated NAT network (`network=default`), but can be toggled to a host bridge (`br0`).

### How to Modify Defaults
All hardware and network configurations are managed inside `libvirt/vm-specs.env`. 
To change the resource allocation or network mode, simply edit the variables in that file before running the provisioning scripts. For example, to switch from the default isolated NAT to a bridged network, change `NETWORK_MODE="isolated"` to `NETWORK_MODE="bridged"`. Hardware allocations can be adjusted based on Node Pools (e.g., all workers) or overridden per-node in the same file.

---

## Repository Architecture

| Directory | Purpose |
| --- | --- |
| **`libvirt/`** | Contains `vm-specs.env` (The **Single Source of Truth** for IP addressing and hardware sizing). |
| **`templates/`** | Base YAML templates for Cloud-Init and Netplan. These are dynamically compiled into `.generated/` during provisioning. |

| **`scripts/`** | The core automation engine to drive the entire lifecycle. |

---

## Prerequisites

Before running any scripts, you **must** have an SSH key pair generated on your host machine. The automation pipeline uses this key to securely communicate with the cluster nodes.
If you do not have one, generate it first:
```bash
ssh-keygen -t ed25519 -N "" -f ~/.ssh/k8s_lab_ed25519
```

---

## Quick Start (1-Click Deploy)

If you just want to build the entire cluster from scratch, simply run the master build script. This will provision the VMs, inject SSH keys, bootstrap Kubernetes, and deploy the monitoring stack.

```bash
./scripts/build-cluster.sh
```

---

## The Step-by-Step Execution Sequence

If you prefer to run the phases manually to see how it works under the hood, follow this sequence:

### Phase 0: Host Setup
Automatically installs all KVM dependencies on your bare-metal Linux host (supports Arch, Ubuntu, Fedora).
```bash
./scripts/host-setup.sh
```

### Phase 1: Virtual Machines
Generates Cloud-Init ISOs and boots all 6 VMs according to `vm-specs.env`.
```bash
./scripts/create-vms.sh
```

### Phase 2: Secure Access
Pushes your public SSH key to the VMs for passwordless script execution.
```bash
./scripts/setup-ssh-keys.sh
```

### Phase 3: Cluster Bootstrapping
Initializes `cp1`, deploys Cilium/Kube-VIP, and joins the remaining control planes and workers.
```bash
./scripts/bootstrap-cluster.sh
```

### Phase 4: Observability Workloads
Pulls the `kubeconfig` to your host and deploys the Prometheus Stack & Metrics Server via Helm.
```bash
./scripts/deploy-addons.sh
```

---

## Next Steps: Visual Cluster Management

Once the cluster is running, it is highly recommended to use a visual IDE to manage your nodes, pods, and workloads instead of relying purely on the command line.

*   **[OpenLens](https://github.com/MuhammedKalkan/OpenLens)**: The open-source, un-restricted version of Lens. Extremely powerful for real-time monitoring and log aggregation.
*   **[Headlamp (Radar)](https://headlamp.dev/)**: A highly extensible, lightweight, and incredibly fast visual UI for Kubernetes.

Simply point these tools to your newly generated `~/.kube/config` file and you will instantly see the entire cluster state!

---

## Day-to-Day Operations

Manage your cluster effortlessly with the included utility scripts:

*   **Start / Stop:** `./scripts/start-cluster.sh` & `./scripts/stop-cluster.sh`
*   **Health Check:** `./scripts/cluster-status.sh`
*   **Backup State:** `./scripts/collect-diagnostics.sh`
*   **Nuke & Rebuild:** `./scripts/destroy-vms.sh`

---

## Deep Dives
*   [Configuration Reference](docs/configuration.md)
*   [Architecture Decisions](docs/architecture.md)
*   [Networking Topology](docs/networking.md)
*   [Troubleshooting Guide](docs/troubleshooting.md)
