#!/bin/bash

###############################################################################
# Kubernetes kubeadm cluster teardown/reset script
#
# Nodes:
#   kube1 - control plane
#   kube2 - worker
#   kube3 - worker
#   kube4 - worker
#
# This script removes Kubernetes state and prepares nodes for a fresh install.
#
# WARNING:
# This will destroy the Kubernetes cluster configuration.
# Any deployed applications, pods, services, and cluster state will be removed.
###############################################################################

set -e


CONTROL_PLANE="kube1"

NODES=(
    "kube1"
    "kube2"
    "kube3"
    "kube4"
)


###############################################################################
# Confirm before destroying cluster
###############################################################################

echo "================================================"
echo "WARNING: Kubernetes cluster reset"
echo "================================================"

echo ""
echo "This will remove:"
echo "  - Kubernetes cluster state"
echo "  - kubeadm configuration"
echo "  - Calico networking"
echo "  - Kubernetes packages"
echo "  - CNI configuration"
echo ""

read -p "Continue? (yes/no): " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
    echo "Aborting."
    exit 0
fi



###############################################################################
# Reset each node
###############################################################################

reset_node() {

NODE=$1

echo ""
echo "========================================="
echo "Resetting $NODE"
echo "========================================="


ssh "$NODE" <<'EOF'

set -e


echo "[1/8] Resetting kubeadm..."

# Ignore errors because some nodes may already be reset
sudo kubeadm reset -f || true



echo "[2/8] Stopping Kubernetes services..."

sudo systemctl stop kubelet || true
sudo systemctl disable kubelet || true



echo "[3/8] Removing Kubernetes packages..."

sudo apt-mark unhold kubeadm kubelet kubectl 2>/dev/null || true

sudo apt purge -y \
    kubeadm \
    kubelet \
    kubectl \
    kubernetes-cni \
    kube* || true


sudo apt autoremove -y



echo "[4/8] Removing Kubernetes directories..."

sudo rm -rf \
    /etc/kubernetes \
    /var/lib/etcd \
    /var/lib/kubelet \
    /etc/cni \
    /opt/cni \
    ~/.kube



echo "[5/8] Cleaning CNI network state..."

sudo rm -rf /var/lib/cni



echo "[6/8] Removing Calico interfaces..."

# Remove common Kubernetes networking interfaces
sudo ip link delete cni0 2>/dev/null || true
sudo ip link delete flannel.1 2>/dev/null || true
sudo ip link delete tunl0 2>/dev/null || true



echo "[7/8] Cleaning iptables rules..."

# Kubernetes creates these chains
# Ignore failures if chains do not exist

sudo iptables -F || true
sudo iptables -t nat -F || true
sudo iptables -t mangle -F || true

sudo iptables -X || true
sudo iptables -t nat -X || true
sudo iptables -t mangle -X || true



echo "[8/8] Cleaning container runtime..."

# Remove Kubernetes containers/images
sudo crictl rm -a -f 2>/dev/null || true
udo crictl rmi --prune 2>/dev/null || true


echo "Node cleanup complete."

EOF

}



###############################################################################
# Run reset on all nodes
###############################################################################

for NODE in "${NODES[@]}"
do
    reset_node "$NODE"
done



###############################################################################
# Optional: Remove containerd state
###############################################################################

echo ""
read -p "Remove all containerd images and containers? (yes/no): " CLEAN_CONTAINERD


if [[ "$CLEAN_CONTAINERD" == "yes" ]]; then

for NODE in "${NODES[@]}"
do

echo "Cleaning containerd on $NODE..."

ssh "$NODE" <<'EOF'

sudo systemctl stop containerd

sudo rm -rf /var/lib/containerd

sudo systemctl start containerd

EOF

done

fi



###############################################################################
# Verify cleanup
###############################################################################

echo ""
echo "========================================="
echo "Cleanup complete"
echo "========================================="

echo ""
echo "You can now rerun the Kubernetes setup script."
