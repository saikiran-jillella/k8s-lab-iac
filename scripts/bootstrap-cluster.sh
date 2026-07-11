#!/bin/bash
set -u  # Catch unset variables, but do NOT use -e/-o pipefail (SSH calls to booting VMs return non-zero transiently)

# Ensure execution context is always the project root
cd "$(dirname "$0")/.."

source libvirt/vm-specs.env

# shellcheck source=scripts/lib/ssh-agent-setup.sh
source "$(dirname "$0")/lib/ssh-agent-setup.sh"




echo "Ensuring all nodes are powered on (Parallel Auto-Wake)..."
for node in "${!CLUSTER_NODES[@]}"; do
    sudo virsh start $node 2>/dev/null || true
done

echo "Waiting for cp1 to be SSH accessible (max 3 minutes)..."
MAX_RETRIES=36
count=0
until ssh $SSH_OPTS $CLUSTER_USER@${CLUSTER_NODES[cp1]} "echo 'cp1 is up'"; do
  sleep 5
  count=$((count+1))
  if [ $count -ge $MAX_RETRIES ]; then
      echo "Error: Timed out waiting for cp1! Did you run setup-ssh-keys.sh? Do the VMs exist?"
      exit 1
  fi
done

echo "[$PRIMARY_CP] Waiting for cloud-init to finish installing Kubernetes (this may take up to 60 minutes)..."
    timeout 3600 ssh $SSH_OPTS $CLUSTER_USER@${CLUSTER_NODES[$PRIMARY_CP]} "echo '$CLUSTER_PASS' | sudo -S bash -c '
        while ! cloud-init status 2>/dev/null | grep -Eq \"(status: done|status: error)\"; do
            line=\$(tail -n 1 /var/log/cloud-init-output.log 2>/dev/null | tr -dc \"[:print:]\")
            printf \"\e[2K\r[$PRIMARY_CP] %s\" \"\$line\"
            sleep 2
        done
        printf \"\n\"
    '" || { if [ $? -eq 130 ]; then echo -e "\nAborted by user (Ctrl+C)"; exit 130; fi; }

    CI_STATUS=$(ssh $SSH_OPTS $CLUSTER_USER@${CLUSTER_NODES[$PRIMARY_CP]} "cloud-init status 2>/dev/null" 2>/dev/null || echo "status: error")
    if echo "$CI_STATUS" | grep -q "status: error"; then
        if ssh $SSH_OPTS $CLUSTER_USER@${CLUSTER_NODES[$PRIMARY_CP]} "which kubeadm" &>/dev/null; then
            echo -e "\n[$(date +'%H:%M:%S')] [$PRIMARY_CP] cloud-init finished with errors, but kubeadm is present. Proceeding."
        else
            echo "[$PRIMARY_CP] FATAL: kubeadm was NOT installed. Cloud-init runcmd failed."
            exit 1
        fi
    elif ! echo "$CI_STATUS" | grep -q "status: done"; then
        echo "[$PRIMARY_CP] Error: Timed out or failed waiting for cloud-init after 60 minutes! Status: $CI_STATUS"
        exit 1
    else
        echo -e "\n[$(date +'%H:%M:%S')] [$PRIMARY_CP] cloud-init provisioning complete!"
    fi

echo "Copying kubeadm configs to $PRIMARY_CP..."
scp $SSH_OPTS .generated/kubeadm-init.yaml $CLUSTER_USER@${CLUSTER_NODES[$PRIMARY_CP]}:/tmp/
scp $SSH_OPTS .generated/kube-vip.yaml $CLUSTER_USER@${CLUSTER_NODES[$PRIMARY_CP]}:/tmp/
scp $SSH_OPTS .generated/cilium-values.yaml $CLUSTER_USER@${CLUSTER_NODES[$PRIMARY_CP]}:/tmp/

echo "Initializing cluster on $PRIMARY_CP..."
ssh $SSH_OPTS $CLUSTER_USER@${CLUSTER_NODES[$PRIMARY_CP]} << EOF
  set -e
  if [ ! -f /etc/kubernetes/admin.conf ]; then
    echo "$CLUSTER_PASS" | sudo -S kubeadm init --config /tmp/kubeadm-init.yaml --upload-certs | tee /tmp/kubeadm-init.out
  else
    echo "$PRIMARY_CP already initialized."
  fi
  
  # Set up kubectl for the regular user
  mkdir -p \$HOME/.kube
  echo "$CLUSTER_PASS" | sudo -S cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config
  echo "$CLUSTER_PASS" | sudo -S chown \$(id -u):\$(id -g) \$HOME/.kube/config

  echo "Deploying kube-vip to $PRIMARY_CP..."
  INTERFACE=\$(ip route ls default | awk '{print \$5}' | head -n 1)
  sed -i "s/{{VIP_INTERFACE}}/\$INTERFACE/g" /tmp/kube-vip.yaml
  echo "$CLUSTER_PASS" | sudo -S cp /tmp/kube-vip.yaml /etc/kubernetes/manifests/
  echo "Waiting for kube-vip to bind the VIP ($CLUSTER_VIP) (this may take up to a minute)..."
  until ping -c 1 -W 1 $CLUSTER_VIP >/dev/null 2>&1; do
    sleep 3
  done
  echo "VIP is up! Waiting 15s for the API Server to stabilize on the VIP..."
  sleep 15

  if ! command -v cilium &> /dev/null; then
    echo "Installing Cilium CLI..."
    CILIUM_CLI_VERSION="v0.19.4"
    GOOS=\$(uname -s | tr A-Z a-z)
    GOARCH=\$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/')
    curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/\${CILIUM_CLI_VERSION}/cilium-\${GOOS}-\${GOARCH}.tar.gz
    echo "$CLUSTER_PASS" | sudo -S tar xzvfC cilium-\${GOOS}-\${GOARCH}.tar.gz /usr/local/bin 2>/dev/null
    rm cilium-\${GOOS}-\${GOARCH}.tar.gz
  else
    echo "Cilium CLI is already installed."
  fi
  if ! kubectl get daemonset cilium -n kube-system >/dev/null 2>&1; then
    cilium install --version 1.19.4 -f /tmp/cilium-values.yaml --wait-duration 60m || cilium install --version 1.19.4 --wait-duration 60m --set routingMode=native --set kubeProxyReplacement=true --set ipv4NativeRoutingCIDR=10.244.0.0/16 --set k8sServiceHost=$CLUSTER_VIP --set k8sServicePort=6443
  else
    echo "Cilium already installed."
  fi
EOF

echo "Retrieving join commands from $PRIMARY_CP..."
CP_JOIN_CMD=$(ssh $SSH_OPTS $CLUSTER_USER@${CLUSTER_NODES[$PRIMARY_CP]} "echo '$CLUSTER_PASS' | sudo -S kubeadm token create --print-join-command 2>/dev/null" | tail -1)
CERT_KEY=$(ssh $SSH_OPTS $CLUSTER_USER@${CLUSTER_NODES[$PRIMARY_CP]} "echo '$CLUSTER_PASS' | sudo -S kubeadm init phase upload-certs --upload-certs 2>/dev/null | tail -1")

echo "Generated CP join command: $CP_JOIN_CMD --control-plane --certificate-key $CERT_KEY"
echo "Generated Worker join command: $CP_JOIN_CMD"

# Write templates
echo "#!/bin/bash" > .generated/join-template.sh
echo "CP_JOIN_CMD=\"$CP_JOIN_CMD --control-plane --certificate-key $CERT_KEY\"" >> .generated/join-template.sh
echo "WORKER_JOIN_CMD=\"$CP_JOIN_CMD\"" >> .generated/join-template.sh

for node in "${!CLUSTER_NODES[@]}"; do
    IP="${CLUSTER_NODES[$node]}"
    if [[ "$node" == "$PRIMARY_CP" ]]; then
        continue # Already initialized above
    fi


    echo "[$node] Waiting for SSH to become available (max 3 minutes)..."
    MAX_RETRIES=36
    count=0
    until ssh $SSH_OPTS $CLUSTER_USER@$IP "echo '$node is up'"; do
        sleep 5
        count=$((count+1))
        if [ $count -ge $MAX_RETRIES ]; then
            echo "[$node] Error: Timed out waiting for SSH! Did you run setup-ssh-keys.sh? Do the VMs exist?"
            exit 1
        fi
    done
    
    echo "[$node] Waiting for cloud-init to finish installing Kubernetes (this may take up to 60 minutes)..."
        timeout 3600 ssh $SSH_OPTS $CLUSTER_USER@$IP "echo '$CLUSTER_PASS' | sudo -S bash -c '
            while ! cloud-init status 2>/dev/null | grep -Eq \"(status: done|status: error)\"; do
                line=\$(tail -n 1 /var/log/cloud-init-output.log 2>/dev/null | tr -dc \"[:print:]\")
                printf \"\e[2K\r[$node] %s\" \"\$line\"
                sleep 2
            done
            printf \"\n\"
        '" || { if [ $? -eq 130 ]; then echo -e "\nAborted by user (Ctrl+C)"; exit 130; fi; }

        CI_STATUS=$(ssh $SSH_OPTS $CLUSTER_USER@$IP "cloud-init status 2>/dev/null" 2>/dev/null || echo "status: error")
        if echo "$CI_STATUS" | grep -q "status: error"; then
            if ssh $SSH_OPTS $CLUSTER_USER@$IP "which kubeadm" &>/dev/null; then
                echo -e "\n[$(date +'%H:%M:%S')] [$node] cloud-init finished with errors. kubeadm is present. Proceeding."
            else
                echo "[$node] FATAL: kubeadm was NOT installed. Cloud-init runcmd failed."
                exit 1
            fi
        elif ! echo "$CI_STATUS" | grep -q "status: done"; then
            echo "[$node] Error: Timed out waiting for cloud-init! Status: $CI_STATUS"
            exit 1
        else
            echo -e "\n[$(date +'%H:%M:%S')] [$node] cloud-init provisioning complete!"
        fi

    if [[ "$node" == cp* ]]; then
        echo "Joining $node as Control Plane..."
        ssh $SSH_OPTS $CLUSTER_USER@$IP "if [ ! -f /etc/kubernetes/kubelet.conf ]; then echo '$CLUSTER_PASS' | sudo -S $CP_JOIN_CMD --control-plane --certificate-key $CERT_KEY; else echo 'Already joined'; fi"
        
        echo "Deploying kube-vip to $node..."
        scp $SSH_OPTS .generated/kube-vip.yaml $CLUSTER_USER@$IP:/tmp/ 2>/dev/null
        ssh $SSH_OPTS $CLUSTER_USER@$IP "INTERFACE=\$(ip route ls default | awk '{print \$5}' | head -n 1) && sed -i \"s/{{VIP_INTERFACE}}/\$INTERFACE/g\" /tmp/kube-vip.yaml && echo '$CLUSTER_PASS' | sudo -S cp /tmp/kube-vip.yaml /etc/kubernetes/manifests/ 2>/dev/null"
    
    elif [[ "$node" == worker* ]]; then
        echo "Joining $node as Worker..."
        ssh $SSH_OPTS $CLUSTER_USER@$IP "if [ ! -f /etc/kubernetes/kubelet.conf ]; then echo '$CLUSTER_PASS' | sudo -S $CP_JOIN_CMD; else echo 'Already joined'; fi"
        
        echo "Labeling $node as worker..."
        ssh $SSH_OPTS $CLUSTER_USER@${CLUSTER_NODES[$PRIMARY_CP]} "kubectl label node $node node-role.kubernetes.io/worker=worker --overwrite"
    else
        echo "Warning: Node $node does not start with 'cp' or 'worker'. Skipping join..."
    fi
done

echo "Waiting for all nodes to transition to Ready state (CNI initialization)..."
for node in "${!CLUSTER_NODES[@]}"; do
    echo -e "\nWaiting for $node to become Ready..."
    echo "-> NOTE: This may take 20-30 minutes while Cilium images download from quay.io."
    echo "-> DO NOT press Ctrl+C. The script will show you live pod progress below:"
    
    while ! ssh $SSH_OPTS $CLUSTER_USER@${CLUSTER_NODES[$PRIMARY_CP]} "kubectl get node $node 2>/dev/null | grep -w 'Ready'" >/dev/null 2>&1; do
        echo -e "\n[$(date +'%H:%M:%S')] Node $node is not yet Ready. Live cluster status:"
        ssh $SSH_OPTS $CLUSTER_USER@${CLUSTER_NODES[$PRIMARY_CP]} "kubectl get pods -n kube-system" 2>/dev/null
        echo -e "\nWaiting 30 seconds before next check..."
        sleep 30
    done
    echo "Node $node is now Ready!"
done

echo "Cluster bootstrapping complete."
