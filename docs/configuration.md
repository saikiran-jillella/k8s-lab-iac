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

## 4. Network Backend & Subnetting (Dynamic Architecture)

The repository uses an intelligent, dynamic network architecture. Instead of manually aligning IP prefixes, subnets, and gateways, you simply select your desired topology mode, and the scripts will automatically query your host machine to mathematically derive the correct IP space.

The `NETWORK_MODE` variable determines how the virtual machines physically connect to the network.

### Option A: Host Bridge (`bridged`) - The "Bare-Metal" Feel
`NETWORK_MODE="bridged"` connects the VMs directly to your physical home router. They completely bypass the host's internal routing and become first-class citizens on your physical network.
*   **Use Case:** You want your physical phone or laptop on the Wi-Fi to be able to directly ping the Kubernetes VMs.
*   **Requirement:** Your host must have a `br0` bridge interface properly configured and attached to the physical network. The scripts will automatically trace `br0`'s default route to determine your home router's subnet and use it as the `IP_PREFIX`.

**Configuration:**
```bash
NETWORK_MODE="bridged"
```

### Option B: Libvirt NAT (`isolated`) - The "Nested" Bubble
`NETWORK_MODE="isolated"` connects the VMs to Libvirt's internal, isolated virtual switch (`virbr0`). Your host machine acts as the router to the outside world.
*   **Use Case:** You want an isolated Sandbox (e.g., testing in a VM), or you don't want to mess with physical Bridge networking.
*   **Requirement:** The libvirt default network must be active. The scripts will automatically detect the IP of `virbr0` (usually `192.168.122.1`) and use it to derive the isolated subnet.

**Configuration:**
```bash
NETWORK_MODE="isolated"
```

---

## 5. OS Image Configuration

*   `OS_VARIANT`: Instructs Libvirt on OS optimizations.
*   `IMAGE_URL`: The direct link to the Cloud Image `.img` file.
