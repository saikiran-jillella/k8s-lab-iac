#!/bin/bash
set -e

echo "Waiting for cp1 to be SSH accessible..."
until ssh -o StrictHostKeyChecking=no saikiran@192.168.0.109 "echo 'cp1 is up'"; do
  sleep 5
done

echo "Copying kubeadm configs to cp1..."
scp -o StrictHostKeyChecking=no kubeadm/kubeadm-init.yaml saikiran@192.168.0.109:/tmp/
scp -o StrictHostKeyChecking=no kubeadm/kube-vip.yaml saikiran@192.168.0.109:/tmp/

echo "Initializing cluster on cp1..."
ssh -o StrictHostKeyChecking=no saikiran@192.168.0.109 << 'EOF'
  sudo kubeadm init --config /tmp/kubeadm-init.yaml --upload-certs | tee /tmp/kubeadm-init.out
  
  # Set up kubectl for saikiran
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

  # Deploy kube-vip
  sudo cp /tmp/kube-vip.yaml /etc/kubernetes/manifests/
EOF

echo "Installing Cilium 1.19.4 on cp1..."
ssh -o StrictHostKeyChecking=no saikiran@192.168.0.109 << 'EOF'
  CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
  GOOS=$(go env GOOS || echo linux)
  GOARCH=$(go env GOARCH || echo amd64)
  curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-${GOOS}-${GOARCH}.tar.gz
  sudo tar xzvfC cilium-${GOOS}-${GOARCH}.tar.gz /usr/local/bin
  rm cilium-${GOOS}-${GOARCH}.tar.gz
  cilium install --version 1.19.4 -f /tmp/cilium-values.yaml || cilium install --version 1.19.4 --set routingMode=native --set kubeProxyReplacement=true --set ipv4NativeRoutingCIDR=10.244.0.0/16 --set k8sServiceHost=192.168.0.120 --set k8sServicePort=6443
EOF

echo "Retrieving join commands from cp1..."
CP_JOIN_CMD=$(ssh -o StrictHostKeyChecking=no saikiran@192.168.0.109 "sudo kubeadm token create --print-join-command")
CERT_KEY=$(ssh -o StrictHostKeyChecking=no saikiran@192.168.0.109 "sudo kubeadm init phase upload-certs --upload-certs | tail -1")

echo "Generated CP join command: $CP_JOIN_CMD --control-plane --certificate-key $CERT_KEY"
echo "Generated Worker join command: $CP_JOIN_CMD"

# Write templates
echo "#!/bin/bash" > kubeadm/join-template.sh
echo "CP_JOIN_CMD=\"$CP_JOIN_CMD --control-plane --certificate-key $CERT_KEY\"" >> kubeadm/join-template.sh
echo "WORKER_JOIN_CMD=\"$CP_JOIN_CMD\"" >> kubeadm/join-template.sh

for node in cp2 cp3; do
    IP=""
    case $node in
        cp2) IP="192.168.0.111" ;;
        cp3) IP="192.168.0.113" ;;
    esac
    echo "Waiting for $node ($IP) to be SSH accessible..."
    until ssh -o StrictHostKeyChecking=no saikiran@$IP "echo '$node is up'"; do sleep 5; done
    echo "Joining $node as Control Plane..."
    ssh -o StrictHostKeyChecking=no saikiran@$IP "sudo $CP_JOIN_CMD --control-plane --certificate-key $CERT_KEY"
done

for node in worker1 worker2; do
    IP=""
    case $node in
        worker1) IP="192.168.0.110" ;;
        worker2) IP="192.168.0.112" ;;
    esac
    echo "Waiting for $node ($IP) to be SSH accessible..."
    until ssh -o StrictHostKeyChecking=no saikiran@$IP "echo '$node is up'"; do sleep 5; done
    echo "Joining $node as Worker..."
    ssh -o StrictHostKeyChecking=no saikiran@$IP "sudo $CP_JOIN_CMD"
done

echo "Cluster bootstrapping complete."
