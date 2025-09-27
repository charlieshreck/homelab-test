#!/bin/bash
set -e

CLUSTER_NAME="homelab-test"
CONTROL_PLANE_IP="10.30.0.11"
K8S_VERSION="v1.31.0"

echo "=== Generating Talos Configs ==="

# Generate secrets
if [ ! -f "secrets.yaml" ]; then
  echo "Generating cluster secrets..."
  talosctl gen secrets -o secrets.yaml
fi

# Generate base configs
echo "Generating machine configs..."
talosctl gen config $CLUSTER_NAME https://${CONTROL_PLANE_IP}:6443 \
  --with-secrets secrets.yaml \
  --kubernetes-version $K8S_VERSION \
  --output-dir ../talos/generated

# Move generated configs to proper location
mv ../talos/generated/controlplane.yaml ../talos/controlplane.yaml
mv ../talos/generated/worker.yaml ../talos/worker.yaml
mv ../talos/generated/talosconfig ~/.talos/config

echo "✅ Configs generated in cluster-bootstrap/talos/"
echo "✅ Talosconfig saved to ~/.talos/config"
