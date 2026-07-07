#!/bin/bash
set -e
source libvirt/vm-specs.env

echo "Waiting for cp1 to be SSH accessible..."
until ssh -o StrictHostKeyChecking=no $CLUSTER_USER@${CLUSTER_NODES[cp1]} "echo 'cp1 is up'"; do
  sleep 5
done

echo "Copying kubeadm configs to cp1..."
scp -o StrictHostKeyChecking=no .generated/kubeadm-init.yaml $CLUSTER_USER@${CLUSTER_NODES[cp1]}:/tmp/
scp -o StrictHostKeyChecking=no .generated/kube-vip.yaml $CLUSTER_USER@${CLUSTER_NODES[cp1]}:/tmp/
scp -o StrictHostKeyChecking=no .generated/cilium-values.yaml $CLUSTER_USER@${CLUSTER_NODES[cp1]}:/tmp/

echo "Initializing cluster on cp1..."
ssh -o StrictHostKeyChecking=no $CLUSTER_USER@${CLUSTER_NODES[cp1]} << 'EOF'
  if [ ! -f /etc/kubernetes/admin.conf ]; then
    echo "$CLUSTER_PASS" | sudo -S kubeadm init --config /tmp/kubeadm-init.yaml --upload-certs | tee /tmp/kubeadm-init.out
  else
    echo "cp1 already initialized."
  fi

  # Set up kubectl for saikiran
  mkdir -p $HOME/.kube
  echo "$CLUSTER_PASS" | sudo -S cp -i /etc/kubernetes/admin.conf $HOME/.kube/config 2>/dev/null || true
  echo "$CLUSTER_PASS" | sudo -S chown $(id -u):$(id -g) $HOME/.kube/config 2>/dev/null || true

  # Deploy kube-vip
  echo "$CLUSTER_PASS" | sudo -S cp /tmp/kube-vip.yaml /etc/kubernetes/manifests/ 2>/dev/null || true
EOF

echo "Installing Cilium 1.19.4 on cp1..."
ssh -o StrictHostKeyChecking=no $CLUSTER_USER@${CLUSTER_NODES[cp1]} << 'EOF'
  CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
  GOOS=$(go env GOOS || echo linux)
  GOARCH=$(go env GOARCH || echo amd64)
  curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-${GOOS}-${GOARCH}.tar.gz
  echo "$CLUSTER_PASS" | sudo -S tar xzvfC cilium-${GOOS}-${GOARCH}.tar.gz /usr/local/bin 2>/dev/null
  rm cilium-${GOOS}-${GOARCH}.tar.gz
  if ! cilium status > /dev/null 2>&1; then
    cilium install --version 1.19.4 -f /tmp/cilium-values.yaml || cilium install --version 1.19.4 --set routingMode=native --set kubeProxyReplacement=true --set ipv4NativeRoutingCIDR=10.244.0.0/16 --set k8sServiceHost=$CLUSTER_VIP --set k8sServicePort=6443
  else
    echo "Cilium already installed."
  fi
EOF

echo "Retrieving join commands from cp1..."
CP_JOIN_CMD=$(ssh -o StrictHostKeyChecking=no $CLUSTER_USER@${CLUSTER_NODES[cp1]} "echo "$CLUSTER_PASS" | sudo -S kubeadm token create --print-join-command 2>/dev/null" | tail -1)
CERT_KEY=$(ssh -o StrictHostKeyChecking=no $CLUSTER_USER@${CLUSTER_NODES[cp1]} "echo "$CLUSTER_PASS" | sudo -S kubeadm init phase upload-certs --upload-certs 2>/dev/null | tail -1")

echo "Generated CP join command: $CP_JOIN_CMD --control-plane --certificate-key $CERT_KEY"
echo "Generated Worker join command: $CP_JOIN_CMD"

# Write templates
echo "#!/bin/bash" > .generated/join-template.sh
echo "CP_JOIN_CMD=\"$CP_JOIN_CMD --control-plane --certificate-key $CERT_KEY\"" >> .generated/join-template.sh
echo "WORKER_JOIN_CMD=\"$CP_JOIN_CMD\"" >> .generated/join-template.sh

source libvirt/vm-specs.env

for node in "${!CLUSTER_NODES[@]}"; do
    IP="${CLUSTER_NODES[$node]}"
    if [[ "$node" == "cp1" ]]; then
        continue # Already initialized above
    fi

    echo "Waiting for $node ($IP) to be SSH accessible..."
    until ssh -o StrictHostKeyChecking=no $CLUSTER_USER@$IP "echo '$node is up'" 2>/dev/null; do sleep 5; done

    if [[ "$node" == cp* ]]; then
        echo "Joining $node as Control Plane..."
        ssh -o StrictHostKeyChecking=no $CLUSTER_USER@$IP "if [ ! -f /etc/kubernetes/kubelet.conf ]; then echo "$CLUSTER_PASS" | sudo -S $CP_JOIN_CMD --control-plane --certificate-key $CERT_KEY; else echo 'Already joined'; fi"
        
        echo "Deploying kube-vip to $node..."
        scp -o StrictHostKeyChecking=no .generated/kube-vip.yaml $CLUSTER_USER@$IP:/tmp/ 2>/dev/null
        ssh -o StrictHostKeyChecking=no $CLUSTER_USER@$IP "echo "$CLUSTER_PASS" | sudo -S cp /tmp/kube-vip.yaml /etc/kubernetes/manifests/ 2>/dev/null"
    
    elif [[ "$node" == worker* ]]; then
        echo "Joining $node as Worker..."
        ssh -o StrictHostKeyChecking=no $CLUSTER_USER@$IP "if [ ! -f /etc/kubernetes/kubelet.conf ]; then echo "$CLUSTER_PASS" | sudo -S $CP_JOIN_CMD; else echo 'Already joined'; fi"
        
        echo "Labeling $node as worker..."
        ssh -o StrictHostKeyChecking=no $CLUSTER_USER@${CLUSTER_NODES[cp1]} "kubectl label node $node node-role.kubernetes.io/worker=worker --overwrite"
    else
        echo "Warning: Node $node does not start with 'cp' or 'worker'. Skipping join..."
    fi
done

echo "Cluster bootstrapping complete."
