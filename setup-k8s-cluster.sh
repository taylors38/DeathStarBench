#!/bin/bash

###############################################################################
# Kubernetes kubeadm cluster setup
#
# Nodes:
#   kube1 - control plane
#   kube2 - worker
#   kube3 - worker
#   kube4 - worker
#
# Runtime:
#   containerd
#
# CNI:
#   Calico
#
# Network:
#   Node network:
#       192.168.128.0/22
#
#   Pod network:
#       10.244.0.0/16
#
# Run this script from a machine with SSH access to all nodes.
###############################################################################

set -e


###############################################################################
# Cluster configuration
###############################################################################

CONTROL_PLANE="kube1"

WORKERS=("kube2" "kube3" "kube4")

CONTROL_PLANE_IP="192.168.128.111"

POD_NETWORK_CIDR="10.244.0.0/16"

CALICO_VERSION="v3.30.2"



###############################################################################
# Install Kubernetes dependencies on a node
###############################################################################

install_node_dependencies() {

    NODE=$1

    echo "========================================="
    echo "Configuring $NODE"
    echo "========================================="


    ssh "$NODE" <<'EOF'

set -e


echo "[1/8] Disabling swap..."

sudo swapoff -a

sudo sed -i '/ swap / s/^/#/' /etc/fstab



echo "[2/8] Loading kernel modules..."

sudo modprobe overlay
sudo modprobe br_netfilter


cat <<MODULES | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
MODULES



echo "[3/8] Configuring sysctl networking..."

cat <<SYSCTL | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
SYSCTL


sudo sysctl --system



echo "[4/8] Installing containerd..."

sudo apt update

sudo apt install -y \
    containerd \
    curl \
    apt-transport-https \
    ca-certificates \
    gpg



sudo mkdir -p /etc/containerd


containerd config default | \
sudo tee /etc/containerd/config.toml >/dev/null


sudo sed -i \
's/SystemdCgroup = false/SystemdCgroup = true/' \
/etc/containerd/config.toml


sudo systemctl restart containerd
sudo systemctl enable containerd



echo "[5/8] Installing Kubernetes packages..."


sudo mkdir -p /etc/apt/keyrings


curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | \
gpg --dearmor --batch --yes | \
sudo dd of=/etc/apt/keyrings/kubernetes.gpg status=none


echo "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /" | \
sudo tee /etc/apt/sources.list.d/kubernetes.list


sudo apt update


sudo apt install -y \
    kubelet \
    kubeadm \
    kubectl


sudo apt-mark hold kubelet kubeadm kubectl


sudo systemctl enable kubelet



echo "[6/8] Restarting kubelet..."

sudo systemctl restart kubelet



echo "[7/8] Checking node preparation..."

echo "Node ready."

EOF

}



###############################################################################
# Prepare nodes
###############################################################################

echo "Preparing all Kubernetes nodes..."

install_node_dependencies "$CONTROL_PLANE"


for NODE in "${WORKERS[@]}"
do
    install_node_dependencies "$NODE"
done



###############################################################################
# Initialize control plane
###############################################################################

echo "========================================="
echo "Initializing Kubernetes control plane"
echo "========================================="


ssh "$CONTROL_PLANE" <<EOF

set -e


sudo kubeadm init \
    --pod-network-cidr=${POD_NETWORK_CIDR} \
    --control-plane-endpoint=${CONTROL_PLANE_IP}



echo "Configuring kubeconfig..."


mkdir -p \$HOME/.kube


sudo cp /etc/kubernetes/admin.conf \$HOME/.kube/config


sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config



echo "Generating worker join command..."


kubeadm token create \
    --print-join-command \
    > \$HOME/join-command.sh



###############################################################################
# Install Calico
###############################################################################

echo "Installing Calico ${CALICO_VERSION}..."


CALICO_FILE="/tmp/calico.yaml"


curl -fsSL \
https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml \
-o \$CALICO_FILE



echo "Configuring Calico pod CIDR..."


sed -i \
"s|# - name: CALICO_IPV4POOL_CIDR|- name: CALICO_IPV4POOL_CIDR|" \
\$CALICO_FILE


sed -i \
"s|#   value: \"192.168.0.0\\/16\"|  value: \"${POD_NETWORK_CIDR}\"|" \
\$CALICO_FILE



echo "Applying Calico..."

kubectl apply -f \$CALICO_FILE

echo "Configuring Calico IP autodetection..."

kubectl -n kube-system set env daemonset/calico-node \
    IP=autodetect \
    IP_AUTODETECTION_METHOD=can-reach=192.168.128.1

echo "Waiting for Calico..."

kubectl rollout status \
daemonset/calico-node \
-n kube-system \
--timeout=180s



echo "Checking Calico IP pool..."

kubectl get ippools.crd.projectcalico.org \
-o jsonpath='{.items[0].spec.cidr}'

echo


EOF



###############################################################################
# Join worker nodes
###############################################################################

echo "========================================="
echo "Joining worker nodes"
echo "========================================="


JOIN_COMMAND=$(ssh "$CONTROL_PLANE" "cat ~/join-command.sh")


for NODE in "${WORKERS[@]}"
do

    echo "Joining $NODE..."

    ssh "$NODE" <<EOF

sudo $JOIN_COMMAND

EOF

done



###############################################################################
# Verify cluster
###############################################################################

echo "========================================="
echo "Cluster status"
echo "========================================="


ssh "$CONTROL_PLANE" <<'EOF'


kubectl get nodes -o wide


echo ""

echo "Calico pods:"
kubectl get pods -n kube-system | grep calico


echo ""

echo "Calico IP Pool:"
kubectl get ippools.crd.projectcalico.org \
-o jsonpath='{.items[0].spec.cidr}'

echo

EOF



echo ""
echo "========================================="
echo "Kubernetes cluster setup complete."
echo "========================================="
