#!/bin/bash
set -e

echo "=== Hybrid Bootstrap: Talos + ArgoCD ==="

# Step 1: Bootstrap Talos cluster (Cilium auto-installs)
./bootstrap-cluster.sh

# Step 2: Wait for Cilium to be ready
echo "Waiting for Cilium CNI..."
kubectl wait --for=condition=Ready pods -n kube-system -l k8s-app=cilium --timeout=300s

# Step 3: Install ArgoCD
echo "Installing ArgoCD..."
kubectl apply -f ../../k8s-platform/argocd/install.yaml
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for ArgoCD..."
kubectl wait --for=condition=Ready pods -n argocd -l app.kubernetes.io/name=argocd-server --timeout=300s

# Step 4: Deploy App-of-Apps (ArgoCD manages rest)
echo "Deploying platform via ArgoCD..."
kubectl apply -f ../../k8s-platform/argocd/app-of-apps.yaml

# Get ArgoCD password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo ""
echo "✅ Bootstrap complete!"
echo ""
echo "ArgoCD URL: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "ArgoCD User: admin"
echo "ArgoCD Pass: $ARGOCD_PASSWORD"
echo ""
echo "ArgoCD will now deploy Longhorn and Traefik from Git"
