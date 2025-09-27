#!/bin/bash
set -e

CONTROL_PLANE_IP="10.30.0.11"
WORKER_IPS=("10.30.0.21" "10.30.0.22")

echo "=== Talos Cluster Bootstrap ==="

# Wait for VMs to be ready
echo "Waiting for nodes to be available..."
for ip in $CONTROL_PLANE_IP "${WORKER_IPS[@]}"; do
  until ping -c 1 $ip &>/dev/null; do
    echo "Waiting for $ip..."
    sleep 5
  done
done

# Apply control plane config
echo "Applying control plane configuration..."
talosctl apply-config --insecure \
  --nodes $CONTROL_PLANE_IP \
  --file ../talos/controlplane.yaml

# Apply worker configs
echo "Applying worker configurations..."
for i in "${!WORKER_IPS[@]}"; do
  ip="${WORKER_IPS[$i]}"
  
  # Copy worker config and update hostname/IP
  cp ../talos/worker.yaml /tmp/worker-$i.yaml
  sed -i "s/talos-worker-01/talos-worker-0$((i+1))/g" /tmp/worker-$i.yaml
  sed -i "s/10.30.0.21/${ip}/g" /tmp/worker-$i.yaml
  
  # Apply GPU patch to first worker
  if [ $i -eq 0 ]; then
    echo "Applying GPU patch to worker 1..."
    talosctl apply-config --insecure \
      --nodes $ip \
      --file /tmp/worker-$i.yaml \
      --config-patch @../talos/patch/gpu-passthrough.yaml
  else
    talosctl apply-config --insecure \
      --nodes $ip \
      --file /tmp/worker-$i.yaml
  fi
done

# Wait for control plane
echo "Waiting for control plane to be ready..."
sleep 60

# Bootstrap etcd
echo "Bootstrapping etcd..."
talosctl bootstrap --nodes $CONTROL_PLANE_IP

# Generate kubeconfig
echo "Generating kubeconfig..."
talosctl --nodes $CONTROL_PLANE_IP kubeconfig ~/.kube/config

# Wait for cluster
echo "Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

echo "✅ Cluster bootstrap complete!"
kubectl get nodes
