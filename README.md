# Homelab Infrastructure

Production-grade Kubernetes homelab with GitOps, automated TLS, and comprehensive media management suite.

## Architecture Overview

### Infrastructure Stack

- **Cluster**: Talos Linux 3-node Kubernetes cluster on Proxmox VE
- **GitOps**: ArgoCD for declarative application deployment
- **Ingress**: Traefik with automated Let's Encrypt TLS certificates
- **Storage**: Mayastor (OpenEBS) for high-performance replicated storage
- **Secrets**: Infisical for centralized secrets management
- **Networking**: Cilium CNI with L2 LoadBalancer announcements
- **Backup**: Velero for cluster backups (MinIO backend)

### Network Architecture

- **Production Network** (10.10.0.0/24): Management and service access
- **Storage Network** (10.11.0.0/24): Dedicated Mayastor storage traffic
- **Dual NICs**: Worker nodes use separate interfaces for traffic isolation

### Key Services

**Platform Services:**
- ArgoCD (GitOps controller) - `argocd.shreck.co.uk`
- Homepage (Dashboard) - `homepage.shreck.co.uk`
- Traefik (Ingress controller)
- cert-manager (TLS automation)
- Velero (Backup system)

**Media Management Suite:**
- Sonarr (TV series) - `sonarr.shreck.co.uk`
- Radarr (Movies) - `radarr.shreck.co.uk`
- Prowlarr (Indexer management) - `prowlarr.shreck.co.uk`
- Overseerr (Request management) - `overseerr.shreck.co.uk`
- Tautulli (Plex analytics) - `tautulli.shreck.co.uk`
- SABnzbd (Usenet downloader) - `sabnzbd.shreck.co.uk`
- Transmission (Torrent client) - `transmission.shreck.co.uk`
- Cleanuparr (Media cleanup) - `cleanuparr.shreck.co.uk`

**Applications:**
- Plex Media Server (LXC with AMD 680M GPU passthrough)
- File Browser - `filebrowser.shreck.co.uk`
- Vaultwarden (Password manager) - `vaultwarden.shreck.co.uk`
- Home Assistant - `homeassistant.shreck.co.uk`
- Karakeep (Bookmark manager) - `karakeep.shreck.co.uk`
- Tasmoadmin (IoT management) - `tasmoadmin.shreck.co.uk`

## Repository Structure

```
homelab-test/
├── infrastructure/
│   ├── terraform/          # IaC for Proxmox VMs/LXCs
│   │   ├── modules/        # Reusable Terraform modules
│   │   ├── main.tf         # Main cluster configuration
│   │   └── plex.tf         # Plex LXC with GPU passthrough
│   └── ansible/            # Configuration management
│       ├── roles/          # Ansible roles (Plex, Restic)
│       └── playbooks/      # Deployment playbooks
├── kubernetes/
│   ├── argocd-apps/        # ArgoCD Application manifests
│   │   ├── platform/       # Platform service applications
│   │   └── applications/   # User application applications
│   ├── platform/           # Platform service configurations
│   │   ├── namespaces/     # Namespace definitions
│   │   ├── traefik/        # Traefik ingress controller
│   │   ├── cert-manager/   # TLS certificate automation
│   │   ├── mayastor/       # Storage system
│   │   ├── velero/         # Backup system
│   │   └── argocd/         # ArgoCD configuration
│   └── applications/       # Application deployments
│       ├── media/          # Media management apps
│       ├── apps/           # General applications
│       └── platform/       # Platform utilities
├── scripts/
│   ├── diagnostic/         # Cluster diagnostic tools
│   ├── deployment/         # Deployment automation
│   └── maintenance/        # Maintenance scripts
└── docs/                   # Documentation
    ├── INGRESS_PATTERN.md  # Standard ingress configuration
    ├── PLEX_*.md           # Plex deployment guides
    └── *.md                # Other documentation

```

## Quick Start

### Prerequisites

- Proxmox VE 8.x host
- Infisical account with secrets configured
- Cloudflare account for DNS/TLS

### Initial Deployment

1. **Configure Terraform Variables**
   ```bash
   cd infrastructure/terraform
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your configuration
   ```

2. **Deploy Infrastructure**
   ```bash
   terraform init
   terraform apply
   ```

3. **Wait for ArgoCD**
   ```bash
   # ArgoCD will automatically deploy all applications
   export KUBECONFIG=$(pwd)/generated/kubeconfig
   kubectl wait --for=condition=available --timeout=10m deployment/argocd-server -n argocd
   ```

4. **Access ArgoCD**
   ```bash
   # Get initial admin password
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   # Open https://argocd.shreck.co.uk
   ```

## Common Operations

### Deploy New Application

1. Create application manifests in `kubernetes/applications/<category>/<app-name>/`
2. Create ArgoCD Application in `kubernetes/argocd-apps/applications/<app-name>-app.yaml`
3. Commit and push - ArgoCD will deploy automatically

### Add Ingress

Follow the standard pattern documented in `docs/INGRESS_PATTERN.md`:
- Use `ingressClassName: traefik`
- Use wildcard TLS certificate `shreck-co-uk-tls`
- Add Homepage annotations for dashboard integration

### Backup and Restore

**Create Backup:**
```bash
velero backup create <backup-name>
```

**Restore:**
```bash
velero restore create --from-backup <backup-name>
```

### Diagnostic Tools

```bash
# Cluster health
scripts/diagnostic/diagnose-cluster.sh

# Mayastor storage
scripts/diagnostic/diagnose-mayastor.sh

# ArgoCD access issues
scripts/diagnostic/diagnose-argocd-access.sh

# L2 announcement issues
scripts/diagnostic/diagnose-l2-announcements.sh
```

## Key Features

### GitOps Workflow

- All infrastructure and applications defined as code
- ArgoCD continuously syncs from Git repository
- Automatic deployment of changes on git push
- Self-healing: ArgoCD corrects manual changes

### Automated TLS

- Let's Encrypt certificates via cert-manager
- Cloudflare DNS challenge for wildcard certificates
- Automatic renewal 30 days before expiration
- Single wildcard cert for all services: `*.shreck.co.uk`

### Secrets Management

- Centralized secrets in Infisical
- InfisicalSecret CRDs sync secrets to Kubernetes
- No hardcoded credentials in Git
- Automatic secret rotation support

### High Availability Storage

- Mayastor provides replicated block storage (3 replicas)
- Dedicated 10GbE storage network for performance
- NVMe-backed storage pools on each worker node
- Supports ReadWriteMany (RWX) volumes

### External Access

- Cloudflare Tunnel for secure external access
- Traefik LoadBalancer with Cilium L2 announcements (10.10.0.150)
- Split-horizon DNS: internal and external resolution

## Secrets Configuration

Required secrets in Infisical at `/kubernetes/` path:

### Core Services
- `CLOUDFLARE_API_TOKEN` - Cloudflare API token for cert-manager
- `CLOUDFLARE_TUNNEL_API_TOKEN` - Tunnel API credentials
- `CLOUDFLARE_ACCOUNT_ID` - Cloudflare account ID
- `CLOUDFLARE_TUNNEL_NAME` - Tunnel name: homelab-shreck-co-uk

### Homepage Integration
- `HOMEPAGE_PROXMOX_API_TOKEN` - Proxmox API access
- `HOMEPAGE_VAR_SONARR_API_KEY` - Sonarr API key
- `HOMEPAGE_VAR_RADARR_API_KEY` - Radarr API key
- `HOMEPAGE_VAR_PROWLARR_API_KEY` - Prowlarr API key
- `HOMEPAGE_VAR_OVERSEERR_API_KEY` - Overseerr API key

### Backup System
- `MINIO_ACCESS_KEY` - MinIO/S3 access key
- `MINIO_SECRET_KEY` - MinIO/S3 secret key
- `RESTIC_PASSWORD` - Restic encryption password
- `PLEX_ROOT_PASSWORD` - Plex LXC root password (optional)

## Monitoring

- Homepage dashboard provides service status overview
- ArgoCD UI shows application sync status
- Traefik dashboard available (internal only)

## Troubleshooting

### Application Not Deploying

1. Check ArgoCD application status:
   ```bash
   kubectl get applications -n argocd
   kubectl describe application <app-name> -n argocd
   ```

2. View application logs in ArgoCD UI

### Ingress Not Working

1. Verify Traefik is running: `kubectl get pods -n traefik`
2. Check certificate: `kubectl get certificate -A`
3. See `docs/INGRESS_PATTERN.md` for detailed troubleshooting

### Storage Issues

1. Check disk pools: `kubectl get diskpool -n mayastor`
2. Verify Mayastor IO engine: `kubectl get pods -n mayastor`
3. Run diagnostic: `scripts/diagnostic/diagnose-mayastor.sh`

## Documentation

- **[INGRESS_PATTERN.md](docs/INGRESS_PATTERN.md)** - Standard ingress configuration guide
- **[PLEX_DEPLOYMENT.md](docs/PLEX_DEPLOYMENT.md)** - Plex LXC setup with GPU passthrough
- **Diagnostic scripts** - Located in `scripts/diagnostic/`

## Technology Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| OS | Talos Linux | Immutable Kubernetes OS |
| Container Runtime | containerd | Container execution |
| CNI | Cilium | Networking and L2 announcements |
| Ingress | Traefik | HTTP/HTTPS routing |
| Storage | Mayastor (OpenEBS) | Replicated block storage |
| GitOps | ArgoCD | Declarative deployments |
| Secrets | Infisical | Secrets management |
| Certificates | cert-manager + Let's Encrypt | Automated TLS |
| Backup | Velero + Restic | Cluster and volume backups |
| Infrastructure | Terraform + Ansible | IaC and configuration |

## Contributing

When adding new services:

1. Follow the standard ingress pattern
2. Use InfisicalSecret for all credentials
3. Create ArgoCD Application manifest
4. Add to Homepage dashboard if user-facing
5. Document any special configuration

## License

Personal homelab infrastructure - not licensed for external use.

## Recent Changes

See commit history for detailed refactoring work including:
- Phase 1: Removed monitoring stack (VictoriaMetrics, Grafana, Dashwise)
- Phase 2: Consolidated folder structure (argocd-apps/, namespaces/)
- Phase 3: Migrated all secrets to Infisical
- Phase 4: Reorganized scripts into diagnostic/deployment/maintenance
- Phase 5: Fixed Terraform timestamp() workarounds
- Phase 6: Documented standard ingress pattern
- Phase 7: Updated documentation and .gitignore
