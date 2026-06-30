# Configuration Reference

The `libvirt/vm-specs.env` file defines the hardware, network, and topology of the cluster.

---

## 1. Node Pools

The lab uses a Node Pool pattern. Nodes inherit hardware specifications based on their role, determined by their hostname prefix.

> [!NOTE]
> **Units:** Memory and Storage variables support standard suffixes like `G`/`GiB`, `GB`, `M`/`MiB`, and `MB`.

### Control Plane 
Applied to nodes starting with `cp` like `cp1` or `cp3`.
*   `CP_VCPUS`: Virtual cores
*   `CP_RAM`: Memory
*   `CP_DISK`: Storage capacity

### Worker Node 
Applied to nodes starting with `worker` like `worker1` or `worker5`.
*   `WORKER_VCPUS`: Virtual cores
*   `WORKER_RAM`: Memory
*   `WORKER_DISK`: Storage capacity

---

## 2. Cluster Topology

The `CLUSTER_NODES` associative array defines the active nodes in the cluster and maps their Hostname to a Static IP Address.

```bash
declare -A CLUSTER_NODES=(
    ["cp1"]="192.168.0.109"
    ["worker1"]="192.168.0.110"
)
```

**Scaling:** Add a new line to this array to add a node. The automation scripts will automatically provision it as a Control Plane or Worker based on the name prefix.

> [!WARNING]
> If nodes are added or removed after the cluster is running, execute `./scripts/create-vms.sh` followed by `./scripts/bootstrap-cluster.sh` to apply the changes.

---

## 3. Individual Node Overrides

The `NODE_*` arrays allow specific nodes to override the defaults inherited from their Node Pool.

```bash
declare -A NODE_RAM=( ["worker1"]=16384 )
```
If a node is not explicitly listed here, it will fall back to its Node Pool defaults.

---

## 4. Network Backend

The `NETWORK_CONFIG` variable determines how the virtual machines connect to the network.

### Option A: Host Bridge (The Default)
`NETWORK_CONFIG="bridge=br0"` connects the VMs directly to your physical network. They receive IPs directly from your physical router.

**Configuration:**
```bash
NETWORK_CONFIG="bridge=br0"
declare -A CLUSTER_NODES=(
    ["cp1"]="192.168.0.109"
    ["cp2"]="192.168.0.110"
    # ... Uses your physical router's subnet (e.g. 192.168.0.x)
)
```

### Option B: Libvirt NAT 
`NETWORK_CONFIG="network=default"` connects the VMs to Libvirt's internal NAT network. They are isolated from the local network but retain internet access.

> [!IMPORTANT]
> When using `network=default`, the static IPs in the `CLUSTER_NODES` array **must** be updated to match the Libvirt internal DHCP subnet, which is typically `192.168.122.0/24`. If you do not update the IPs, the VMs will have no route to the internet!

**Example: Switching to Libvirt NAT**
Change the variables in `vm-specs.env` to match the `192.168.122.x` subnet:
```bash
NETWORK_CONFIG="network=default"
CLUSTER_VIP="192.168.122.120" # Don't forget to update the VIP!

declare -A CLUSTER_NODES=(
    ["cp1"]="192.168.122.109"
    ["cp2"]="192.168.122.110"
    # ... Uses Libvirt's internal subnet
)
```

---

## 5. OS Image Configuration

*   `OS_VARIANT`: Instructs Libvirt on OS optimizations.
*   `IMAGE_URL`: The direct link to the Cloud Image `.img` file.
