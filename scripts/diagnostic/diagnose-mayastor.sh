#!/bin/bash
# Mayastor Deployment Diagnostic Script
# Run this on terra LXC to diagnose and fix missing Mayastor operator

set -e

export KUBECONFIG=~/homelab-test/infrastructure/terraform/generated/kubeconfig

echo "=========================================="
echo "Mayastor Deployment Diagnostic"
echo "=========================================="

echo -e "\n=== Step 1: Check ArgoCD Applications ==="
echo "Looking for all Mayastor applications..."
kubectl get applications -n argocd | grep mayastor || echo "NO MAYASTOR APPS FOUND!"

echo -e "\n=== Step 2: Check if CRDs are installed ==="
echo "Looking for DiskPool CRD..."
kubectl get crd diskpools.openebs.io 2>/dev/null && echo "✓ DiskPool CRD EXISTS" || echo "✗ DiskPool CRD MISSING"

echo -e "\n=== Step 3: Check Mayastor pods ==="
kubectl get pods -n mayastor 2>/dev/null || echo "No mayastor namespace or pods"

echo -e "\n=========================================="
echo "DIAGNOSIS:"
echo "=========================================="

# Check if mayastor operator app exists
if kubectl get application mayastor -n argocd &>/dev/null; then
    echo "✓ mayastor operator application EXISTS"

    # Check its status
    STATUS=$(kubectl get application mayastor -n argocd -o jsonpath='{.status.sync.status}')
    HEALTH=$(kubectl get application mayastor -n argocd -o jsonpath='{.status.health.status}')
    echo "  Status: $STATUS"
    echo "  Health: $HEALTH"

    if [ "$STATUS" != "Synced" ] || [ "$HEALTH" != "Healthy" ]; then
        echo ""
        echo "⚠️  Mayastor operator exists but is not healthy!"
        echo "Checking application details..."
        kubectl describe application mayastor -n argocd | tail -20
    fi
else
    echo "✗ mayastor operator application MISSING"
    echo ""
    echo "=========================================="
    echo "FIX REQUIRED:"
    echo "=========================================="
    echo ""
    echo "The mayastor operator application is missing from ArgoCD."
    echo "This application installs the CRDs that DiskPools need."
    echo ""
    echo "Run this command to create all three Mayastor applications:"
    echo ""
    echo "  kubectl apply -f ~/homelab-test/kubernetes/platform/mayastor-app.yaml"
    echo ""
    echo "Then monitor with:"
    echo "  kubectl get applications -n argocd | grep mayastor"
    echo ""
    exit 1
fi

echo -e "\n=========================================="
echo "Next steps:"
echo "=========================================="
echo "1. Fix any unhealthy applications shown above"
echo "2. Wait for CRDs to be installed by the operator"
echo "3. Once CRDs exist, mayastor-config will sync successfully"
