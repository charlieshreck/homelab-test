#!/bin/bash
# ArgoCD Access Diagnostic Script
# Run this on terra LXC after terraform apply completes

set -e

export KUBECONFIG=~/homelab-test/infrastructure/terraform/generated/kubeconfig

echo "=========================================="
echo "ArgoCD Access Diagnostic"
echo "=========================================="

echo -e "\n=== Step 1: Check ArgoCD namespace exists ==="
kubectl get namespace argocd 2>/dev/null && echo "✓ ArgoCD namespace EXISTS" || {
    echo "✗ ArgoCD namespace MISSING - Terraform didn't complete!"
    exit 1
}

echo -e "\n=== Step 2: Check ArgoCD pods ==="
kubectl get pods -n argocd

echo -e "\n=== Step 3: Check ArgoCD server service ==="
kubectl get svc argocd-server -n argocd -o wide

echo -e "\n=== Step 4: Check LoadBalancer IP assignment ==="
LB_IP=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
if [ -z "$LB_IP" ]; then
    echo "✗ No LoadBalancer IP assigned!"
    echo ""
    echo "Checking Cilium status..."
    kubectl get pods -n kube-system | grep cilium
    echo ""
    echo "⚠️  Cilium may not be ready yet. Wait 1-2 minutes and try again."
else
    echo "✓ LoadBalancer IP: $LB_IP"

    if [ "$LB_IP" != "10.10.0.81" ]; then
        echo "⚠️  WARNING: Expected 10.10.0.81 but got $LB_IP"
    fi
fi

echo -e "\n=== Step 5: Check which node is running ArgoCD server ==="
ARGOCD_NODE=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].spec.nodeName}')
ARGOCD_POD=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].metadata.name}')
echo "ArgoCD server pod: $ARGOCD_POD"
echo "Running on node: $ARGOCD_NODE"

if [ -n "$ARGOCD_NODE" ]; then
    NODE_IP=$(kubectl get node $ARGOCD_NODE -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
    echo "Node IP: $NODE_IP"
fi

echo -e "\n=== Step 6: Test connectivity from terra LXC ==="
echo "Testing ping to ArgoCD LoadBalancer IP..."
if [ -n "$LB_IP" ]; then
    if ping -c 2 $LB_IP &>/dev/null; then
        echo "✓ Ping successful to $LB_IP"
    else
        echo "✗ Ping FAILED to $LB_IP"
        echo ""
        echo "This means Cilium L2 announcements are not working properly."
    fi

    echo -e "\nTesting HTTP connection..."
    if curl -s -m 5 http://$LB_IP &>/dev/null; then
        echo "✓ HTTP connection successful!"
        echo ""
        echo "ArgoCD UI should be accessible at: http://$LB_IP"
    else
        echo "✗ HTTP connection FAILED"
        echo ""
        echo "Checking if ArgoCD server pod is ready..."
        kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server
    fi
fi

echo -e "\n=== Step 7: Check Cilium L2 Announcement Policy ==="
kubectl get ciliuml2announcementpolicy -A 2>/dev/null || echo "No L2 announcement policies found"

echo -e "\n=== Step 8: Get ArgoCD admin password ==="
echo "ArgoCD admin password:"
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' 2>/dev/null | base64 -d && echo || echo "Secret not found yet"

echo -e "\n=========================================="
echo "SUMMARY:"
echo "=========================================="

if [ -n "$LB_IP" ] && ping -c 1 $LB_IP &>/dev/null && curl -s -m 5 http://$LB_IP &>/dev/null; then
    echo "✓ ArgoCD is accessible!"
    echo ""
    echo "Access ArgoCD at: http://$LB_IP"
    echo "Username: admin"
    echo -n "Password: "
    kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' 2>/dev/null | base64 -d && echo
elif [ -z "$LB_IP" ]; then
    echo "✗ LoadBalancer IP not assigned - Cilium not ready"
    echo ""
    echo "Wait 2-3 minutes for Cilium to fully initialize, then run this script again."
elif ! ping -c 1 $LB_IP &>/dev/null; then
    echo "✗ Cannot ping LoadBalancer IP - L2 announcements not working"
    echo ""
    echo "Check Cilium logs:"
    echo "  kubectl logs -n kube-system -l k8s-app=cilium --tail=50 | grep -i announce"
else
    echo "✗ ArgoCD server not responding"
    echo ""
    echo "Check ArgoCD server logs:"
    echo "  kubectl logs -n argocd $ARGOCD_POD"
fi

echo ""
echo "=========================================="
echo "Next steps:"
echo "=========================================="
echo "1. Ensure all pods are Running (check Step 2 above)"
echo "2. Ensure LoadBalancer IP is assigned (check Step 4 above)"
echo "3. Ensure connectivity works (check Step 6 above)"
echo "4. Access ArgoCD at http://10.10.0.81 (or the IP shown above)"
