# Terraform Infrastructure

## Quick Start

```bash
# Initialize
terraform init

# Plan
terraform plan

# Apply
terraform apply

# Output kubeconfig
export KUBECONFIG=$(pwd)/generated/kubeconfig
```

## Structure

- `main.tf` - Main orchestration
- `providers.tf` - Provider configurations
- `variables.tf` - Variable definitions
- `locals.tf` - Computed values
- `data.tf` - Data sources
- `outputs.tf` - Outputs
- `vault.tf` - Vault deployment
- `external-secrets.tf` - External Secrets Operator

## Variables

Copy `terraform.tfvars.example` to `terraform.tfvars` and configure:

- Proxmox connection details
- Network configuration
- VM specifications
- GitOps repository URL
- Cloudflare credentials (or use Vault)
