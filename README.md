# Homelab Test Infrastructure

GitOps-based Kubernetes homelab running on Proxmox with Talos OS.

## Architecture

- **Proxmox Host**: 10.30.0.10
- **Control Plane**: 10.30.0.11 (2 cores, 4GB RAM, 100GB disk on Kerrier)
- **Worker 1**: 10.30.0.21 (4 cores, 4GB RAM, 400GB disk on Restormal, Intel GPU passthrough)
- **Worker 2**: 10.30.0.22 (2 cores, 4GB RAM, 400GB disk on Restormal)
- **TrueNAS**: 172.20.0.10 (2 cores, 4GB RAM, 32GB disk on Trelawney)

## Networks

- **Production**: 10.30.0.0/24
- **Proxmox Internal**: 172.10.0.0/24
- **TrueNAS**: 172.20.0.0/24

## Storage Pools

- **Kerrier** (500GB): VM system disks
- **Restormal** (950GB): Longhorn distributed storage
- **Trelawney**: TrueNAS storage

## Stack

- **OS**: Talos v1.11.2
- **Kubernetes**: v1.31.0
- **CNI**: Cilium (auto-installed via Talos)
- **Storage**: Longhorn (on Restormal NVMe)
- **Ingress**: Traefik with local SSL
- **GitOps**: ArgoCD
- **Remote Access**: Cloudflare Tunnel

## Repository Structure

```
├── infrastructure/          # Terraform configs for Proxmox VMs
├── cluster-bootstrap/       # Talos cluster bootstrap
├── k8s-platform/           # Core platform (ArgoCD, Longhorn, Traefik)
├── applications/           # User applications
└── .github/workflows/      # CI/CD pipelines
```

## Deployment

### Prerequisites
1. Upload ISOs to Proxmox `local` storage:
   - `talos-amd64.iso` (v1.11.2)
   - `TrueNAS-SCALE-latest.iso`
2. Find GPU PCI ID: `lspci | grep VGA`
3. Update configs (see UPDATE CHECKLIST)
4. Add GitHub secret: `PROXMOX_PASSWORD`

### Deploy Infrastructure
```bash
cd infrastructure/terraform
terraform init
terraform plan
terraform apply
```

### Bootstrap Cluster
```bash
cd cluster-bootstrap/scripts
./bootstrap-hybrid.sh
```

This will:
1. Bootstrap Talos cluster (Cilium auto-installs)
2. Install ArgoCD
3. ArgoCD deploys Longhorn + Traefik from Git

### Access ArgoCD
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# User: admin
# Pass: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## GitOps Workflow

All changes via Git:
1. Update manifests in repository
2. Commit and push to GitHub
3. ArgoCD auto-syncs within 3 minutes

## GPU Transcoding

Worker 1 has Intel iGPU passthrough for Plex hardware transcoding.

## Notes

- Talos manages Cilium CNI automatically
- ArgoCD manages all platform components and applications
- TrueNAS on isolated 172.20.0.0/24 network for media storage
- Longhorn uses 800GB of Restormal NVMe (~150GB reserved for overhead)
