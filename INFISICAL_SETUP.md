# Infisical Secrets Setup Guide

This document explains how to configure all secrets in Infisical for the infrastructure automation.

## Overview

All sensitive secrets are now fetched from Infisical by Terraform during `terraform apply`. This eliminates the need to store secrets in `terraform.tfvars` locally.

**Project:** `homelab-test-5-ig-k`
**Environment:** `prod`
**Secrets Path:** `/backups`

---

## Required Secrets

Create the following secrets in Infisical at `/backups` in the `prod` environment:

### 1. PLEX_ROOT_PASSWORD

**Description:** Root password for the Plex LXC container

**Where to get it:**
- Generate a strong password (e.g., `openssl rand -base64 32`)
- Example: `A7x!kM9p#L2qR$vW5tBn&8cD`

**Infisical Setup:**
```
Name: PLEX_ROOT_PASSWORD
Value: <your_strong_password>
```

---

### 2. PLEX_CLAIM_TOKEN (Optional)

**Description:** Auto-claim token for Plex server

**Where to get it:**
1. Go to https://www.plex.tv/claim
2. Sign in with your Plex account
3. Copy the claim token (valid for 4 minutes)

**Infisical Setup:**
```
Name: PLEX_CLAIM_TOKEN
Value: claim-xxxxxxxxxxxxxx
```

**Note:** If you don't set this, leave it empty. You can claim the server manually after deployment via the Plex web UI at `http://10.10.0.60:32400`.

---

### 3. MINIO_ACCESS_KEY

**Description:** MinIO access key for backup storage

**Where to get it:**
1. SSH to TrueNAS (or use TrueNAS web UI)
2. Navigate to MinIO web UI: `http://10.20.0.100:9000`
3. Go to **Administration** → **Access Keys**
4. Create a new access key with permissions for:
   - `velero-backups` bucket (read/write)
   - `restic-backups` bucket (read/write)
5. Copy the generated **Access Key**

**Infisical Setup:**
```
Name: MINIO_ACCESS_KEY
Value: <access_key_from_minio>
```

**Example:** `AKIAIOSFODNN7EXAMPLE`

---

### 4. MINIO_SECRET_KEY

**Description:** MinIO secret key for backup storage

**Where to get it:**
- From the same MinIO access key creation step above
- Copy the generated **Secret Key**

**Infisical Setup:**
```
Name: MINIO_SECRET_KEY
Value: <secret_key_from_minio>
```

**Example:** `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`

---

### 5. RESTIC_PASSWORD

**Description:** Encryption password for Restic backups

**Where to get it:**
- Generate a strong random password (different from PLEX_ROOT_PASSWORD)
- This encrypts all restic backup repositories
- Example: `openssl rand -base64 32`

**Infisical Setup:**
```
Name: RESTIC_PASSWORD
Value: <strong_random_password>
```

**Important:** Keep this password safe. If lost, your backups become unrecoverable.

---

## Step-by-Step Setup

### 1. Create `/backups` Path in Infisical

1. Log into Infisical: https://app.infisical.com
2. Select project: `homelab-test-5-ig-k`
3. Select environment: `prod`
4. Click **Create Secret Path** or navigate to existing `/backups` path
5. If `/backups` doesn't exist:
   - Click on "/" path
   - Click **Create Secret Path**
   - Name: `backups`
   - Create

### 2. Add Secrets to `/backups`

For each secret listed above:

1. Navigate to `/backups` path
2. Click **Create Secret**
3. Enter the name (e.g., `PLEX_ROOT_PASSWORD`)
4. Enter the value
5. Click **Create**

### 3. Verify Terraform Access

Once secrets are created, verify Terraform can access them:

```bash
cd infrastructure/terraform

# Initialize Terraform
terraform init

# Check if secrets are accessible (will fail if any are missing)
terraform plan -out=tfplan

# The plan should show the Plex and Restic modules being created
```

---

## Expected Infisical Structure

```
homelab-test-5-ig-k (project)
└── prod (environment)
    ├── /infrastructure
    │   └── GITHUB_TOKEN
    │
    └── /backups
        ├── PLEX_ROOT_PASSWORD
        ├── PLEX_CLAIM_TOKEN (optional)
        ├── MINIO_ACCESS_KEY
        ├── MINIO_SECRET_KEY
        └── RESTIC_PASSWORD
```

---

## MinIO Setup Prerequisites

Before adding MinIO credentials to Infisical, ensure MinIO is configured on TrueNAS:

### 1. Create Buckets

SSH to TrueNAS or use the MinIO web UI to create:
- Bucket: `velero-backups` (for Kubernetes backups via Velero)
- Bucket: `restic-backups` (for LXC/VM backups via Restic)

### 2. Create Access Key

1. Open MinIO web UI: `http://10.20.0.100:9000`
2. Sign in with TrueNAS admin credentials
3. Go to **Administration** → **Access Keys**
4. Click **Create Access Key**
5. Copy the **Access Key** and **Secret Key** immediately (secret key won't be shown again)

### 3. Assign Bucket Permissions

If using a non-admin access key, ensure it has permissions for:
- `velero-backups/*` (read/write)
- `restic-backups/*` (read/write)

---

## Terraform Workflow

Once secrets are in Infisical:

1. **Plan changes:** `terraform plan`
   - Terraform automatically fetches secrets from Infisical
   - Secrets are NOT shown in plan output

2. **Apply changes:** `terraform apply tfplan`
   - Plex LXC container is created with `PLEX_ROOT_PASSWORD`
   - Restic backup agent is configured with `RESTIC_PASSWORD` and MinIO credentials
   - Velero's Kubernetes secret is created via InfisicalSecret CRD (in Kubernetes)

3. **No local secrets:** Your `terraform.tfvars` file contains NO sensitive data

---

## Troubleshooting

### Terraform fails with "secret not found"

**Solution:** Check that secrets exist in Infisical at `/backups` path:

```bash
# Manually verify secret access (if infisical CLI is installed)
infisical export --projectId=<id> --env=prod --secretsPath=/backups
```

### MinIO credentials rejected

**Solution:** Verify the access key has permissions:
- MinIO UI → Access Keys → Check bucket permissions
- Ensure both `velero-backups` and `restic-backups` are listed

### Plex container can't authenticate

**Solution:** Verify `PLEX_ROOT_PASSWORD` is correct:
```bash
# From Plex container
ssh root@10.10.0.60
# Log in with the password set in PLEX_ROOT_PASSWORD
```

---

## Security Best Practices

✅ **DO:**
- Store secrets only in Infisical
- Generate strong, unique passwords for each secret
- Rotate MinIO access keys periodically
- Keep Infisical credentials safe (`var.infisical_client_id`, `var.infisical_client_secret`)
- Use `.gitignore` to prevent accidental commits

❌ **DON'T:**
- Store secrets in `terraform.tfvars`
- Commit secrets to Git
- Share access keys in messages or logs
- Use the same password for multiple services
- Log secrets in Terraform output

---

## Updating Secrets

To update a secret (e.g., rotate MinIO keys):

1. Update the secret value in Infisical at `/backups`
2. Run `terraform apply` again
3. Terraform will re-deploy affected resources with new secrets

Example: Rotating MinIO credentials
```bash
# 1. Update MINIO_ACCESS_KEY and MINIO_SECRET_KEY in Infisical
# 2. Run terraform
terraform apply

# Result: Velero and Restic configurations updated automatically
```

---

## Related Files

- `infrastructure/terraform/infisical-secrets.tf` - Fetches secrets from Infisical
- `infrastructure/terraform/plex.tf` - Uses fetched secrets for Plex deployment
- `kubernetes/platform/velero/infisical-secret.yaml` - Syncs MinIO secrets to Kubernetes
- `infrastructure/terraform/variables.tf` - Lists all variables (now mostly non-sensitive)

---

## Support

If you encounter issues:

1. Check Infisical secret paths: `homelab-test-5-ig-k` → `prod` → `/backups`
2. Verify MinIO buckets exist and are accessible: `http://10.20.0.100:9000`
3. Test Infisical auth: `terraform init -upgrade`
4. Check Terraform logs: `TF_LOG=DEBUG terraform plan`
