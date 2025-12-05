#!/bin/bash
# Cluster Diagnostics Script - ImagePullBackOff Investigation

echo "=========================================="
echo "CLUSTER DIAGNOSTICS - ImagePullBackOff"
echo "=========================================="
echo ""

echo "1. Checking specific pod errors..."
echo "-----------------------------------"
echo "Mayastor etcd pod error:"
kubectl describe pod -n mayastor mayastor-etcd-0 | grep -A 20 "Events:"
echo ""

echo "Traefik pod error:"
kubectl describe pod -n traefik $(kubectl get pods -n traefik -o name | head -1 | cut -d'/' -f2) | grep -A 20 "Events:"
echo ""

echo "2. Checking node conditions..."
echo "-----------------------------------"
kubectl get nodes -o wide
echo ""
kubectl describe nodes | grep -A 5 "Conditions:"
echo ""

echo "3. Checking DNS resolution from a node..."
echo "-----------------------------------"
kubectl run --rm -i --tty dns-test --image=busybox --restart=Never -- nslookup docker.io || true
echo ""

echo "4. Checking network connectivity to registries..."
echo "-----------------------------------"
echo "Testing docker.io:"
kubectl run --rm -i --tty net-test --image=busybox --restart=Never -- wget -O- https://registry-1.docker.io/v2/ 2>&1 || true
echo ""

echo "5. Checking Cilium network status..."
echo "-----------------------------------"
kubectl get pods -n kube-system -l k8s-app=cilium
kubectl exec -n kube-system $(kubectl get pods -n kube-system -l k8s-app=cilium -o name | head -1) -- cilium status
echo ""

echo "6. Checking for image pull secrets..."
echo "-----------------------------------"
kubectl get secrets -A | grep docker
echo ""

echo "7. Checking Mayastor IO engine pending reason..."
echo "-----------------------------------"
kubectl describe pod -n mayastor $(kubectl get pods -n mayastor -l app=io-engine -o name | head -1 | cut -d'/' -f2) | grep -A 30 "Events:"
echo ""

echo "8. Checking node labels for Mayastor..."
echo "-----------------------------------"
kubectl get nodes --show-labels | grep -i mayastor
echo ""

echo "9. Checking container runtime..."
echo "-----------------------------------"
kubectl get nodes -o wide
echo ""

echo "10. Getting detailed error from a failing pod..."
echo "-----------------------------------"
kubectl get events -n mayastor --sort-by='.lastTimestamp' | tail -20
echo ""

echo "=========================================="
echo "DIAGNOSTICS COMPLETE"
echo "=========================================="
