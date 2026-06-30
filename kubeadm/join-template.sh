#!/bin/bash
CP_JOIN_CMD="kubeadm join $CLUSTER_VIP:6443 --token qhb33n.et8p5ioke3ssyt9r --discovery-token-ca-cert-hash sha256:7166bc3f9ac05b4c173ceb4ad57b9e19d13c56ec04fb70f80e4baac74fb01797  --control-plane --certificate-key 74d2396810612410cbd49802eb4adcbec725bb5c6f8a4c285d258a50d8031a69"
WORKER_JOIN_CMD="kubeadm join $CLUSTER_VIP:6443 --token qhb33n.et8p5ioke3ssyt9r --discovery-token-ca-cert-hash sha256:7166bc3f9ac05b4c173ceb4ad57b9e19d13c56ec04fb70f80e4baac74fb01797 "
