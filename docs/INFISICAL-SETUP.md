# Infisical Setup Guide

Infisical is used for secure secrets management in your homelab. This guide walks through creating an Infisical account, setting up a project, and generating Universal Auth credentials for Kubernetes integration.

## ⚠️ CRITICAL: Secrets Management

**Infisical credentials are managed by Terraform and MUST NOT be committed to Git.**

- Infisical operator namespace and credentials secret are provisioned by `infrastructure/terraform/infisical.tf`
- ArgoCD does NOT manage Infisical credentials - Terraform is the single source of truth
- Credentials are stored in `infrastructure/terraform/terraform.tfvars` which is in `.gitignore`
- Use `terraform.tfvars.example` as a template with placeholder values
- Never commit plaintext secrets to Git, regardless of branch

## Overview

**What is Infisical?**
- Cloud-based secrets management platform (like HashiCorp Vault)
- Free tier available with sufficient features for homelab use
- Kubernetes operator syncs secrets from Infisical to K8s automatically

**Architecture:**
```
Infisical Cloud (secrets storage)
    ↓
Universal Auth (machine credentials)
    ↓
Infisical Kubernetes Operator (running in your cluster)
    ↓
Kubernetes Secrets (auto-synced)
    ↓
Your Applications
```

## Step 1: Create Infisical Account

1. Go to [https://app.infisical.com/signup](https://app.infisical.com/signup)

2. Sign up with your email:
   - Email: `charlieshreck@gmail.com` (or your preferred email)
   - Create a strong password
   - Verify your email address

3. Complete the onboarding wizard

## Step 2: Create a Project

1. After logging in, click **"Create Project"**

2. Project settings:
   - **Name**: `homelab-prod` (or `homelab-test`)
   - **Description**: "Production homelab secrets for shreck.co.uk"
   - Click **"Create"**

3. You'll be redirected to the project dashboard

## Step 3: Add Secrets to Your Project

Navigate to your project and add the following secrets:

### Required Secrets

#### 1. Cloudflare Secrets (for cert-manager DNS challenges)
Path: `/` (root)

| Secret Key | Value | Description |
|---|---|---|
| `CLOUDFLARE_API_TOKEN` | `<your-api-token>` | Cloudflare API token with DNS edit permissions |
| `CLOUDFLARE_EMAIL` | `charlieshreck@gmail.com` | Your Cloudflare account email |

#### 2. Cloudflare Tunnel Token (for cloudflared)
Path: `/cloudflared`

| Secret Key | Value | Description |
|---|---|---|
| `TUNNEL_TOKEN` | `<tunnel-token>` | Token from Cloudflare Zero Trust tunnel |

#### 3. Media App Secrets (optional)
Path: `/media`

| Secret Key | Value | Description |
|---|---|---|
| `SONARR_API_KEY` | `<generated>` | Sonarr API key |
| `RADARR_API_KEY` | `<generated>` | Radarr API key |
| `PROWLARR_API_KEY` | `<generated>` | Prowlarr API key |
| `OVERSEERR_API_KEY` | `<generated>` | Overseerr API key |

**Note:** Media app API keys are auto-generated after first deployment. You can add them later.

## Step 4: Create Universal Auth Credentials

Universal Auth allows your Kubernetes cluster to authenticate to Infisical using client ID and secret (like a service account).

### Create Machine Identity

1. In your Infisical project, navigate to:
   - **Project Settings** (gear icon) → **Access Control** → **Machine Identities**

2. Click **"Create Machine Identity"**

3. Configure:
   - **Name**: `kubernetes-operator`
   - **Description**: "Kubernetes Infisical operator for homelab cluster"
   - Click **"Create"**

4. Set permissions:
   - **Role**: `Admin` or `Developer` (needs read access to all secrets)
   - **Environment**: `Production` (or your environment name)
   - Click **"Save"**

### Generate Universal Auth Credentials

1. Click on your newly created machine identity `kubernetes-operator`

2. Navigate to the **"Universal Auth"** tab

3. Click **"Generate Credentials"**

4. You'll receive:
   ```
   Client ID: 26428618-6807-4a12-a461-33242ec1af50
   Client Secret: 8176c36e0e932f660327236ad288cfb1edbbced739d9c2d074d8cedabf492ee3
   ```

5. **IMPORTANT:** Copy both values immediately! The client secret is shown only once.

### Security Best Practices

- **Store securely**: Save credentials in a password manager (not plaintext)
- **Rotate regularly**: Generate new credentials every 90 days
- **Limit permissions**: Use minimum required permissions (read-only if possible)
- **Monitor access**: Check Infisical audit logs periodically

## Step 5: Update Terraform Configuration

Update your `infrastructure/terraform/terraform.tfvars`:

```hcl
# Infisical Configuration
infisical_client_id     = "26428618-6807-4a12-a461-33242ec1af50"
infisical_client_secret = "8176c36e0e932f660327236ad288cfb1edbbced739d9c2d074d8cedabf492ee3"
```

**Security Note:** These credentials are stored in `terraform.tfvars` which should be in `.gitignore`. Never commit secrets to Git!

## Step 6: Verify Infisical Deployment

After running `terraform apply`, Infisical operator will be deployed automatically.

### Check Operator Status

```bash
# Check operator pods
kubectl get pods -n infisical-operator-system

# Expected output:
NAME                                                    READY   STATUS
infisical-operator-controller-manager-xxxxx-xxxxx      2/2     Running
```

### Check Secret Sync

```bash
# Check InfisicalSecret resources (custom resources that define which secrets to sync)
kubectl get infisicalsecrets -A

# Example output:
NAMESPACE   NAME                AGE
traefik     cloudflare-secret   5m
media       sonarr-secret       5m
```

### Verify Synced Secrets

```bash
# Check that Kubernetes secrets were created
kubectl get secrets -n traefik | grep cloudflare

# Check secret contents (base64 encoded)
kubectl get secret cloudflare-api-token -n traefik -o jsonpath='{.data.api-token}' | base64 -d
```

## Troubleshooting

### Operator Not Starting

**Symptoms:**
```
kubectl get pods -n infisical-operator-system
# Shows CrashLoopBackOff or Error
```

**Solution:**
```bash
# Check operator logs
kubectl logs -n infisical-operator-system -l control-plane=controller-manager

# Common issues:
# 1. Invalid credentials → Check client_id and client_secret in terraform.tfvars
# 2. Network issues → Check cluster internet connectivity
# 3. Rate limiting → Wait 5 minutes and restart operator
```

### Secrets Not Syncing

**Symptoms:**
```
kubectl get infisicalsecrets -n traefik
# Shows "Sync failed" in status
```

**Solution:**
```bash
# Describe the InfisicalSecret resource
kubectl describe infisicalsecret cloudflare-secret -n traefik

# Check events section for error messages
# Common issues:
# 1. Secret path not found in Infisical → Verify path and secret keys
# 2. Permission denied → Check machine identity has read access
# 3. Project not found → Verify project ID in InfisicalSecret spec
```

### How to Get Project ID

If you need your Infisical project ID:

1. Go to your Infisical project dashboard
2. Click **Project Settings** (gear icon)
3. Look for **Project ID** under "General"
4. Copy the ID (format: `64abc123def456789`)

## Using Secrets in Applications

### Example: InfisicalSecret Resource

```yaml
apiVersion: secrets.infisical.com/v1alpha1
kind: InfisicalSecret
metadata:
  name: cloudflare-secret
  namespace: traefik
spec:
  # Reference to Infisical auth secret (created by Terraform)
  authentication:
    universalAuth:
      secretsScope:
        projectSlug: homelab-prod
        envSlug: prod
        secretsPath: /
      credentialsRef:
        secretName: infisical-universal-auth
        secretNamespace: infisical-operator-system

  # Kubernetes secret to create
  managedSecretReference:
    secretName: cloudflare-api-token
    secretNamespace: traefik
    creationPolicy: Orphan

  # Which secrets to sync from Infisical
  resyncInterval: 60
  secrets:
    - secretName: CLOUDFLARE_API_TOKEN
      secretKey: api-token
```

### Using the Secret in a Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  containers:
  - name: app
    image: my-app:latest
    env:
    - name: CLOUDFLARE_TOKEN
      valueFrom:
        secretKeyRef:
          name: cloudflare-api-token
          key: api-token
```

## Rotating Credentials

### Rotate Universal Auth Credentials

1. In Infisical, navigate to your machine identity
2. Click **"Generate Credentials"** to create new credentials
3. Update `terraform.tfvars` with new credentials
4. Run `terraform apply`
5. Wait for operator to restart with new credentials
6. Delete old credentials from Infisical

### Rotate Application Secrets

1. Update secret value in Infisical web UI
2. Infisical operator will automatically sync to Kubernetes (default: 60 seconds)
3. Restart pods that use the secret (if they don't watch for changes)

```bash
kubectl rollout restart deployment/my-app -n namespace
```

## Backup and Disaster Recovery

### Export Secrets (for backup)

**Via Infisical CLI:**
```bash
# Install Infisical CLI
brew install infisical/get-cli/infisical  # macOS
# or
curl -1sLf 'https://dl.cloudsmith.io/public/infisical/infisical-cli/setup.deb.sh' | sudo -E bash
sudo apt-get install infisical  # Linux

# Login
infisical login

# Export secrets
infisical secrets export --project-id=<project-id> --env=prod --format=json > secrets-backup.json
```

**Important:** Store backups securely (encrypted drive, password manager)

### Restore from Backup

1. Create new Infisical project
2. Import secrets via CLI or web UI
3. Update `terraform.tfvars` with new project credentials
4. Run `terraform apply`

## Alternative: Self-Hosted Infisical

If you prefer to self-host Infisical (for air-gapped environments):

```bash
# Deploy Infisical with Docker Compose
git clone https://github.com/Infisical/infisical
cd infisical
docker-compose up -d

# Access at http://localhost:8080
```

**Note:** Self-hosting requires additional maintenance (database, backups, updates)

## Additional Resources

- [Infisical Documentation](https://infisical.com/docs)
- [Kubernetes Operator Guide](https://infisical.com/docs/integrations/platforms/kubernetes)
- [Universal Auth Documentation](https://infisical.com/docs/documentation/platform/identities/universal-auth)
- [Infisical CLI](https://infisical.com/docs/cli/overview)

---

**Next Steps:**
1. ✅ Complete Infisical setup
2. → Configure Cloudflare API keys (see CLOUDFLARE-SETUP.md)
3. → Deploy homelab cluster with Terraform
