# Repository Structure

This document explains the organization of the homelab infrastructure repository.

## Directory Layout

### ArgoCD Application Manifests
All ArgoCD Application custom resources are centralized for easy management:

- **`kubernetes/argocd-apps/platform/`** - Platform service Applications
  - Core infrastructure: Traefik, Mayastor, cert-manager, ArgoCD itself
  - Sync waves ensure proper deployment ordering

- **`kubernetes/argocd-apps/applications/`** - User-facing application Applications
  - Media apps: Sonarr, Radarr, Prowlarr, Overseerr, Transmission
  - Utilities: Homepage, Filebrowser, Vaultwarden, Home Assistant

### Kubernetes Resource Manifests
The actual Kubernetes resources (Deployments, Services, Ingresses) are organized separately:

- **`kubernetes/platform/<service>/`** - Platform service configurations
  - Each platform service has its own directory with resources and Helm values
  - Examples:
    - `kubernetes/platform/traefik/` - Traefik ingress controller config
    - `kubernetes/platform/mayastor/` - Mayastor storage system
    - `kubernetes/platform/cert-manager/` - TLS certificate automation
    - `kubernetes/platform/argocd/` - ArgoCD configuration

- **`kubernetes/applications/<category>/<app>/`** - Application manifests
  - Each application has a directory containing:
    - `deployment.yaml` - Kubernetes Deployment
    - `ingress.yaml` - Standard Kubernetes Ingress (following INGRESS_PATTERN.md)
    - `kustomization.yaml` - Kustomize configuration
  - Categories:
    - `media/` - Media automation apps (Sonarr, Radarr, etc.)
    - `apps/` - General applications (Homepage, Filebrowser, etc.)
    - `platform/` - Platform utilities (Renovate, etc.)

### Namespace Definitions
Namespaces are defined in two locations depending on their purpose:

- **`kubernetes/platform/namespaces/`** - Platform namespaces requiring special configuration
  - Pod Security Standards labels
  - Resource quotas
  - NetworkPolicies
  - Example: `mayastor-namespace.yaml` with privileged PSS

- **Co-located with applications** - Simple application namespaces
  - `kubernetes/applications/media/namespace.yaml`
  - `kubernetes/applications/apps/namespace.yaml`

### Infrastructure as Code
- **`infrastructure/terraform/`** - Proxmox VM/LXC provisioning
  - `modules/` - Reusable Terraform modules (talos-vm, restic-lxc, etc.)
  - `main.tf` - Main cluster configuration
  - `plex.tf` - Plex LXC with GPU passthrough

- **`infrastructure/ansible/`** - Configuration management
  - `roles/` - Ansible roles for system configuration
  - `playbooks/` - Deployment automation

### Bootstrap Process
The deployment follows a hierarchical pattern:

1. **Infrastructure Layer** (Terraform)
   - Provisions Proxmox VMs with Talos OS
   - Bootstraps Kubernetes cluster
   - Deploys ArgoCD via Terraform

2. **Bootstrap Layer** (ArgoCD)
   - `kubernetes/bootstrap/app-of-apps.yaml` is applied
   - Points to `kubernetes/argocd-apps/platform/`
   - Creates Application resources for all platform services

3. **Platform Layer** (ArgoCD sync-wave 0-2)
   - Traefik (wave 0) - Ingress controller
   - Mayastor, cert-manager, Infisical (wave 1) - Core services
   - Mayastor config, app ingresses (wave 2) - Configuration

4. **Application Layer** (ArgoCD sync-wave 3)
   - `applications-app.yaml` in platform creates umbrella
   - Points to `kubernetes/argocd-apps/applications/`
   - Deploys all user-facing applications

### Scripts
- **`scripts/diagnostic/`** - Cluster diagnostic tools
  - `diagnose-cluster.sh` - Overall cluster health
  - `diagnose-mayastor.sh` - Storage system checks
  - `diagnose-argocd-access.sh` - ArgoCD connectivity
  - `diagnose-l2-announcements.sh` - Cilium LoadBalancer

- **`scripts/deployment/`** - Deployment automation
- **`scripts/maintenance/`** - Maintenance tasks

### Documentation
- **`docs/`** - Comprehensive documentation
  - `INGRESS_PATTERN.md` - Standard ingress template and guidelines
  - `STRUCTURE.md` - This file (repository organization)
  - `PLEX_DEPLOYMENT.md` - Plex LXC with GPU passthrough
  - Other deployment and configuration guides

## Design Principles

### Separation of Concerns
- **ArgoCD Applications** (`argocd-apps/`) vs **Kubernetes Resources** (`platform/`, `applications/`)
- This allows ArgoCD to manage what gets deployed, while keeping the actual resource definitions separate

### GitOps First
- All infrastructure and applications defined as code
- Git is the single source of truth
- ArgoCD continuously reconciles cluster state with Git
- Self-healing: manual changes are automatically reverted

### Consistency
- All applications follow the same structure pattern
- Standard ingress configuration (see `docs/INGRESS_PATTERN.md`)
- Centralized secrets via Infisical
- Uniform namespace management

### Discoverability
- Clear directory structure makes it easy to find resources
- Documentation co-located with relevant components
- Standard patterns reduce cognitive load

## Adding New Services

### Adding a Platform Service
1. Create resource directory: `kubernetes/platform/<service>/`
2. Add manifests or Helm values
3. Create ArgoCD Application: `kubernetes/argocd-apps/platform/<service>-app.yaml`
4. Set appropriate sync-wave annotation
5. Commit and push - ArgoCD will deploy automatically

### Adding an Application
1. Create app directory: `kubernetes/applications/<category>/<app>/`
2. Add `deployment.yaml`, `ingress.yaml` (following INGRESS_PATTERN.md), `kustomization.yaml`
3. Create ArgoCD Application: `kubernetes/argocd-apps/applications/<app>-app.yaml`
4. Add Homepage annotations to ingress if user-facing
5. Commit and push - ArgoCD will deploy automatically

### Adding Secrets
1. Add secrets to Infisical at path `/kubernetes/`
2. Create InfisicalSecret CRD in application manifests
3. Reference the synced secret in Deployment

## Related Documentation
- [Ingress Pattern Guide](INGRESS_PATTERN.md)
- [Plex Deployment](PLEX_DEPLOYMENT.md)
- [Main README](../README.md)
