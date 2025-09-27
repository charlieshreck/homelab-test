#!/bin/bash

# Create main directories
mkdir -p homelab-test/{.github/workflows,infrastructure/{terraform/modules/{talos-vm,truenas-vm},scripts},cluster-bootstrap/{talos/patch,scripts},k8s-platform/{cilium,longhorn,traefik/certificates,argocd,cloudflare-tunnel},applications/{media/plex,monitoring/{prometheus,grafana},argocd-apps},scripts}

cd homelab-test

# Create .gitignore
cat > .gitignore << 'EOF'
*.tfstate
*.tfstate.backup
.terraform/
.terraform.lock.hcl
*.tfvars.secret
kubeconfig
talosconfig
.env
EOF

# Create placeholder files
touch .github/workflows/{infrastructure.yml,validate.yml}
touch infrastructure/terraform/{main.tf,variables.tf,terraform.tfvars,outputs.tf}
touch infrastructure/terraform/modules/talos-vm/main.tf
touch infrastructure/terraform/modules/truenas-vm/main.tf
touch infrastructure/scripts/deploy.sh
touch cluster-bootstrap/talos/{controlplane.yaml,worker.yaml}
touch cluster-bootstrap/talos/patch/gpu-passthrough.yaml
touch cluster-bootstrap/scripts/{generate-configs.sh,bootstrap-cluster.sh}
touch k8s-platform/cilium/values.yaml
touch k8s-platform/longhorn/values.yaml
touch k8s-platform/traefik/values.yaml
touch k8s-platform/argocd/{install.yaml,applications.yaml}
touch k8s-platform/cloudflare-tunnel/deployment.yaml
touch applications/media/plex/{deployment.yaml,service.yaml,pvc.yaml}
touch applications/argocd-apps/{media.yaml,monitoring.yaml}
touch scripts/deploy-from-git.sh

# Copy your existing script
cp ~/terraform_install.sh scripts/ 2>/dev/null || touch scripts/terraform_install.sh

# Create README
cat > README.md << 'EOF'
# Homelab Test Infrastructure

## Networks
- Production: 10.30.0.0/24
- Proxmox Internal: 172.10.0.0/24
- TrueNAS: 172.20.0.0/24

## Structure
- `infrastructure/` - Terraform configs for Proxmox VMs
- `cluster-bootstrap/` - Talos OS configs
- `k8s-platform/` - Core K8s components
- `applications/` - ArgoCD-managed apps

## Deployment
```bash
./scripts/deploy-from-git.sh

EOF
