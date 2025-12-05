#!/bin/bash
# Cilium L2 Announcement Diagnostic Script
# Diagnose why LoadBalancer IPs are getting ICMP redirects

set -e

export KUBECONFIG=~/homelab-test/infrastructure/terraform/generated/kubeconfig

echo "=========================================="
echo "Cilium L2 Announcement Diagnostic"
echo "=========================================="

echo -e "\n=== Step 1: Check ArgoCD Service Configuration ==="
echo "ArgoCD server service:"
kubectl get svc argocd-server -n argocd

echo -e "\nChecking externalTrafficPolicy:"
ETP=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.externalTrafficPolicy}')
if [ "$ETP" == "Local" ]; then
    echo "✓ externalTrafficPolicy: Local (correct)"
else
    echo "✗ externalTrafficPolicy: $ETP (should be Local!)"
fi

echo -e "\n=== Step 2: Find which node has the ArgoCD pod ==="
ARGOCD_NODE=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].spec.nodeName}')
ARGOCD_POD=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].metadata.name}')
echo "ArgoCD server pod: $ARGOCD_POD"
echo "Running on node: $ARGOCD_NODE"

if [ -n "$ARGOCD_NODE" ]; then
    NODE_IP=$(kubectl get node $ARGOCD_NODE -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
    echo "Node IP: $NODE_IP"
    echo ""
    echo "⚠️  With externalTrafficPolicy: Local, ONLY node $NODE_IP should announce 10.10.0.81"
fi

echo -e "\n=== Step 3: Check Cilium Configuration ==="
echo "Checking if Cilium devices is configured:"
DEVICES=$(kubectl get configmap cilium-config -n kube-system -o jsonpath='{.data.devices}' 2>/dev/null || echo "NOT SET")
if [ "$DEVICES" == "ens18" ]; then
    echo "✓ Cilium devices: ens18 (correct)"
else
    echo "✗ Cilium devices: $DEVICES (should be ens18!)"
fi

echo -e "\nChecking L2 announcement is enabled:"
L2_ENABLED=$(kubectl get configmap cilium-config -n kube-system -o jsonpath='{.data.enable-l2-announcements}' 2>/dev/null || echo "NOT SET")
echo "enable-l2-announcements: $L2_ENABLED"

echo -e "\n=== Step 4: Check Cilium L2 Announcement Policy ==="
kubectl get ciliuml2announcementpolicy -A

echo -e "\nL2 Announcement Policy details:"
kubectl get ciliuml2announcementpolicy l2-announcement-policy -o yaml | grep -A10 "spec:"

echo -e "\n=== Step 5: Check Cilium LoadBalancer IP Pool ==="
kubectl get ciliumloadbalancerippool -A

echo -e "\n=== Step 6: Check Cilium Pods ==="
echo "Cilium pods on each node:"
kubectl get pods -n kube-system -l k8s-app=cilium -o wide

echo -e "\n=== Step 7: Check which IPs Cilium is managing ==="
echo "LoadBalancer services:"
kubectl get svc -A -o wide | grep LoadBalancer

echo -e "\n=== Step 8: Test L2 Lease (which node is announcing) ==="
echo "Checking Cilium L2 announcement leases..."
kubectl get lease -n kube-system | grep cilium-l2announce || echo "No L2 announcement leases found"

echo -e "\n=== Step 9: Check Cilium Status on Worker Nodes ==="
for node in $(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[*].metadata.name}'); do
    echo -e "\n--- Node: $node ---"
    NODE_IP=$(kubectl get node $node -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
    echo "Node IP: $NODE_IP"

    # Get Cilium pod on this node
    CILIUM_POD=$(kubectl get pods -n kube-system -l k8s-app=cilium --field-selector spec.nodeName=$node -o jsonpath='{.items[0].metadata.name}')

    if [ -n "$CILIUM_POD" ]; then
        echo "Checking if $node is announcing 10.10.0.81..."
        kubectl logs -n kube-system $CILIUM_POD --tail=50 | grep -i "10.10.0.81\|announce" | tail -5 || echo "No announcement logs found"
    fi
done

echo -e "\n=========================================="
echo "DIAGNOSIS:"
echo "=========================================="

if [ "$ETP" != "Local" ]; then
    echo "✗ PROBLEM: externalTrafficPolicy is NOT set to Local"
    echo ""
    echo "This means ALL worker nodes will announce the LoadBalancer IP,"
    echo "causing routing conflicts and ICMP redirects."
    echo ""
    echo "FIX: The Terraform config has externalTrafficPolicy: Local,"
    echo "but it's not being applied. This could be a Helm chart issue."
    echo ""
    echo "Try manually patching the service:"
    echo "  kubectl patch svc argocd-server -n argocd -p '{\"spec\":{\"externalTrafficPolicy\":\"Local\"}}'"
elif [ "$DEVICES" != "ens18" ]; then
    echo "✗ PROBLEM: Cilium devices not set to ens18"
    echo ""
    echo "Cilium doesn't know which interface to use for L2 announcements."
    echo ""
    echo "FIX: This should be set in Terraform, but may need Helm upgrade:"
    echo "  kubectl get configmap cilium-config -n kube-system -o yaml"
else
    echo "✓ Configuration looks correct"
    echo ""
    echo "If still getting ICMP redirects, the issue may be:"
    echo "1. ARP cache on your machine (run: sudo arp -d 10.10.0.81)"
    echo "2. OPNsense firewall blocking traffic"
    echo "3. Timing issue - wait 1-2 more minutes for leases to settle"
    echo ""
    echo "Expected behavior with externalTrafficPolicy: Local:"
    echo "  - ONLY $ARGOCD_NODE ($NODE_IP) should announce 10.10.0.81"
    echo "  - Traffic should go directly to $NODE_IP"
    echo "  - No ICMP redirects should occur"
fi
