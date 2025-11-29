# ==============================================================================
# infisical-secrets.tf - Secrets Management for Terraform
# ==============================================================================
#
# SECRETS MANAGEMENT APPROACH:
#
# Secrets are stored in Infisical at: homelab-test-5-ig-k/prod/backups
# For Terraform, provide secrets via environment variables:
#
#   export TF_VAR_plex_root_password="value_from_infisical"
#   export TF_VAR_plex_claim_token="value_from_infisical"
#   export TF_VAR_minio_access_key="value_from_infisical"
#   export TF_VAR_minio_secret_key="value_from_infisical"
#   export TF_VAR_restic_encryption_password="value_from_infisical"
#
# Or use Infisical CLI to load them automatically:
#
#   infisical run -- terraform plan
#   infisical run -- terraform apply
#
# For Kubernetes, secrets are synced directly via InfisicalSecret CRD
# in kubernetes/platform/velero/infisical-secret.yaml
#

# The variable values are provided via:
# 1. Environment variables (TF_VAR_*)
# 2. terraform.tfvars (local, not committed)
# 3. -var flags on command line
# 4. Infisical CLI integration
#
# No secret values are hardcoded in this file.
