# ==============================================================================
# infisical-secrets.tf - Fetch secrets from Infisical for Terraform use
# ==============================================================================

# Configure Infisical provider
provider "infisical" {
  host = "https://app.infisical.com/api"

  auth = {
    universal_auth = {
      client_id     = var.infisical_client_id
      client_secret = var.infisical_client_secret
    }
  }
}

# Fetch backup secrets from Infisical
data "infisical_secrets" "backup_secrets" {
  env_slug      = "prod"
  project_slug  = "homelab-test-5-ig-k"
  folder_path   = "/backups"
}

# Extract individual secrets for easier access
locals {
  minio_access_key          = data.infisical_secrets.backup_secrets.secrets["MINIO_ACCESS_KEY"]
  minio_secret_key          = data.infisical_secrets.backup_secrets.secrets["MINIO_SECRET_KEY"]
  restic_encryption_password = data.infisical_secrets.backup_secrets.secrets["RESTIC_PASSWORD"]
  plex_root_password        = data.infisical_secrets.backup_secrets.secrets["PLEX_ROOT_PASSWORD"]
  plex_claim_token          = try(data.infisical_secrets.backup_secrets.secrets["PLEX_CLAIM_TOKEN"], "")
}
