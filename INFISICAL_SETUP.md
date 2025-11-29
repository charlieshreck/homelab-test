# Infisical Secrets Setup Guide

This document explains how to configure all secrets in Infisical for the infrastructure automation.

## Overview

All sensitive secrets are stored in Infisical. Terraform and Kubernetes access them differently:

- **Kubernetes:** InfisicalSecret CRD syncs secrets automatically from Infisical
- **Terraform:** Secrets provided via environment variables or terraform.tfvars

**Project:** `homelab-test-5-ig-k`
**Environment:** `prod`
**Secrets Path:** `/backups`

---

## Required Secrets

Create the following secrets in Infisical at `/backups` in the `prod` environment:

### 1. PLEX_ROOT_PASSWORD

**Description:** Root password for the Plex LXC container

**Where to get it:**
- Generate a strong password: `openssl rand -base64 32`
- Example: `A7x!kM9p#L2qR$vW5tBn&8cD`

**Infisical Setup:**
```
Path: /backups
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

Once secrets are stored in Infisical, provide them to Terraform before running:

### Option 1: Using Environment Variables (Recommended)

```bash
# Set environment variables from Infisical values
export TF_VAR_plex_root_password="<from Infisical /backups>"
export TF_VAR_plex_claim_token="<from Infisical /backups>"
export TF_VAR_minio_access_key="<from Infisical /backups>"
export TF_VAR_minio_secret_key="<from Infisical /backups>"
export TF_VAR_restic_encryption_password="<from Infisical /backups>"

# Then run Terraform
terraform init
terraform plan
terraform apply
```

### Option 2: Using Infisical CLI (Easiest)

```bash
# Use Infisical CLI to automatically load secrets as environment variables
infisical login
infisical run -- terraform init
infisical run -- terraform plan
infisical run -- terraform apply
```

The Infisical CLI will:
- Authenticate to Infisical
- Load all secrets from `/backups` path as environment variables
- Set `TF_VAR_*` variables automatically
- Run Terraform with access to all secrets

### Option 3: Using terraform.tfvars (Less Secure)

Create `infrastructure/terraform/terraform.tfvars` (DO NOT COMMIT):

```hcl
plex_root_password         = "<from Infisical>"
plex_claim_token           = "<from Infisical>"
minio_access_key           = "<from Infisical>"
minio_secret_key           = "<from Infisical>"
restic_encryption_password = "<from Infisical>"
```

Then run normally:
```bash
terraform plan
terraform apply
```

⚠️ **WARNING:** If using Option 3, make sure `.gitignore` includes `terraform.tfvars` to prevent accidental commits.

### Verification

After running Terraform:
```bash
# Check that Plex LXC was created
# Check that Restic backup is configured on the container
# Verify Kubernetes secrets were synced via Velero
```

---

## Troubleshooting

### Terraform fails with "required argument missing"

**Solution:** Environment variables not set. Provide secrets before running Terraform:

**Option A - Using environment variables:**
```bash
export TF_VAR_plex_root_password="<value>"
export TF_VAR_plex_claim_token="<value>"
export TF_VAR_minio_access_key="<value>"
export TF_VAR_minio_secret_key="<value>"
export TF_VAR_restic_encryption_password="<value>"
terraform plan
```

**Option B - Using Infisical CLI:**
```bash
infisical run -- terraform plan
```

**Option C - Using terraform.tfvars:**
```bash
# Create infrastructure/terraform/terraform.tfvars with secret values
terraform plan
```

### Terraform fails to access Infisical secrets

**Solution:** Use one of the options above to provide secrets. Terraform no longer fetches directly from Infisical API.

### MinIO credentials rejected during Velero/Restic deployment

**Solution:** Verify:
1. Secrets were provided to Terraform (check environment variables)
2. MinIO access key has bucket permissions:
   - MinIO UI → Access Keys → Check permissions for `velero-backups` and `restic-backups`
3. Buckets exist on MinIO:
   - MinIO UI → Buckets → Verify both backup buckets are created

### Plex container SSH access fails

**Solution:** Verify the password:
```bash
# SSH to Plex container
ssh root@10.10.0.60

# Password is the value of PLEX_ROOT_PASSWORD from Infisical
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

- `infrastructure/terraform/infisical-secrets.tf` - Documents how to provide secrets to Terraform
- `infrastructure/terraform/plex.tf` - Uses secrets for Plex and Restic deployment
- `infrastructure/terraform/variables.tf` - Lists all Terraform variables
- `kubernetes/platform/velero/infisical-secret.yaml` - Syncs MinIO secrets to Kubernetes via InfisicalSecret CRD
- `kubernetes/platform/velero/kustomization.yaml` - Kubernetes secret management
- `.pre-commit-config.yaml` - Security checks to prevent secret commits

---

## Support

If you encounter issues:

1. Check Infisical secret paths: `homelab-test-5-ig-k` → `prod` → `/backups`
2. Verify MinIO buckets exist and are accessible: `http://10.20.0.100:9000`
3. Test Infisical auth: `terraform init -upgrade`
4. Check Terraform logs: `TF_LOG=DEBUG terraform plan`
