# Domain Update Summary: shreck.io → shreck.co.uk

## Changes Made

All references to `shreck.io` have been updated to `shreck.co.uk` throughout the homelab infrastructure.

### Files Updated

#### Terraform Configuration
- ✅ `infrastructure/terraform/terraform.tfvars`
  - `cloudflare_domain = "shreck.co.uk"`

#### Kubernetes Platform Services
- ✅ `kubernetes/platform/argocd/resources/ingress.yaml`
  - Host: `argocd.shreck.co.uk`
  - TLS secret: `shreck-co-uk-tls`

- ✅ `kubernetes/platform/cert-manager/resources/reflector.yaml`
  - Certificate name: `wildcard-shreck-co-uk`
  - Secret name: `shreck-co-uk-tls`
  - DNS names: `shreck.co.uk`, `*.shreck.co.uk`

- ✅ `kubernetes/platform/cert-manager/resources/cluster-issuer.yaml`
  - DNS zones: `shreck.co.uk`

- ✅ `kubernetes/platform/cloudflared/resources/values.yaml`
  - Tunnel routes: `*.shreck.co.uk`, `shreck.co.uk`

- ✅ `kubernetes/platform/longhorn/resources/ingress.yaml`
  - Host: `longhorn.shreck.co.uk`

#### Kubernetes Applications
- ✅ `kubernetes/applications/media/sonarr/ingress.yaml` → `sonarr.shreck.co.uk`
- ✅ `kubernetes/applications/media/radarr/ingress.yaml` → `radarr.shreck.co.uk`
- ✅ `kubernetes/applications/media/prowlarr/ingress.yaml` → `prowlarr.shreck.co.uk`
- ✅ `kubernetes/applications/media/overseerr/ingress.yaml` → `overseerr.shreck.co.uk`
- ✅ `kubernetes/applications/media/transmission/ingress.yaml` → `transmission.shreck.co.uk`
- ✅ `kubernetes/applications/public/dashboard/ingressroute-external.yaml` → `shreck.co.uk`

### New Documentation
- ✅ `docs/INFISICAL-SETUP.md` - Complete Infisical secrets management guide
- ✅ `docs/CLOUDFLARE-SETUP.md` - Complete Cloudflare DNS and API setup guide

## Required Actions Before Deployment

### 1. Cloudflare Configuration

#### A. Update DNS Records
Navigate to Cloudflare Dashboard → DNS → Records and verify/update:

| Type | Name | Content | Proxy | Notes |
|------|------|---------|-------|-------|
| A | @ | 10.10.0.80 | ❌ DNS only | Root domain |
| A | * | 10.10.0.80 | ❌ DNS only | Wildcard for all subdomains |

**These should point to your Traefik LoadBalancer IP (10.10.0.80)**

#### B. Create API Token for cert-manager
1. Go to Profile → API Tokens → Create Token
2. Use "Edit zone DNS" template
3. Permissions:
   - Zone - DNS - Edit
   - Zone - Zone - Read
4. Zone Resources:
   - Include - Specific zone - shreck.co.uk
5. Copy the token (shown only once!)

#### C. Create Cloudflare Tunnel
1. Go to Zero Trust → Networks → Tunnels
2. Create tunnel: `homelab-shreck-co-uk`
3. Copy the tunnel token
4. Add routes for your services (argocd, sonarr, radarr, etc.)

📖 **Detailed instructions:** See `docs/CLOUDFLARE-SETUP.md`

### 2. Infisical Configuration

#### A. Create Infisical Project
1. Sign up at https://app.infisical.com
2. Create project: `homelab-prod`

#### B. Add Required Secrets
Add these secrets to your Infisical project:

**Path: `/`**
```
CLOUDFLARE_API_TOKEN = <your-api-token-from-step-1B>
CLOUDFLARE_EMAIL = charlieshreck@gmail.com
```

**Path: `/cloudflared`**
```
TUNNEL_TOKEN = <your-tunnel-token-from-step-1C>
```

#### C. Create Universal Auth Credentials
1. Project Settings → Access Control → Machine Identities
2. Create identity: `kubernetes-operator`
3. Generate Universal Auth credentials
4. Copy Client ID and Client Secret

📖 **Detailed instructions:** See `docs/INFISICAL-SETUP.md`

### 3. Update Terraform Configuration

Update `infrastructure/terraform/terraform.tfvars` with your Infisical credentials:

```hcl
# Infisical Configuration
infisical_client_id     = "YOUR-CLIENT-ID-HERE"
infisical_client_secret = "YOUR-CLIENT-SECRET-HERE"
```

**⚠️ IMPORTANT:** Keep `terraform.tfvars` in `.gitignore` - never commit secrets to Git!

### 4. Verify Configuration

Before deploying, verify all changes:

```bash
# Check domain in Terraform
grep cloudflare_domain infrastructure/terraform/terraform.tfvars
# Should show: cloudflare_domain = "shreck.co.uk"

# Check Kubernetes ingress files
grep -r "shreck" kubernetes/ --include="*.yaml" | grep -v "charlieshreck"
# Should only show shreck.co.uk (no shreck.io)

# Verify cert-manager certificate
cat kubernetes/platform/cert-manager/resources/reflector.yaml | grep -A 2 "dnsNames"
# Should show:
#   - shreck.co.uk
#   - "*.shreck.co.uk"
```

## Deployment Checklist

- [ ] **Proxmox**: Create vmbr1 bridge for storage network (10.11.0.0/24)
- [ ] **Cloudflare**: Configure DNS records for shreck.co.uk
- [ ] **Cloudflare**: Create API token for cert-manager
- [ ] **Cloudflare**: Create Cloudflare Tunnel and get token
- [ ] **Infisical**: Create account and project
- [ ] **Infisical**: Add Cloudflare secrets (API token, email, tunnel token)
- [ ] **Infisical**: Generate Universal Auth credentials
- [ ] **Terraform**: Update terraform.tfvars with Infisical credentials
- [ ] **Deploy**: Run `terraform apply`
- [ ] **Verify**: Check certificates, tunnel connection, and service access

## Deployment

Once all prerequisites are complete:

```bash
cd infrastructure/terraform

# Initialize Terraform (if first time)
terraform init

# Review changes
terraform plan

# Deploy infrastructure
terraform apply

# Wait ~30 minutes for full deployment
```

## Verification Steps

After deployment:

```bash
# 1. Check cluster health
kubectl get nodes

# 2. Check Infisical operator
kubectl get pods -n infisical-operator-system

# 3. Check secrets synced from Infisical
kubectl get secrets -n traefik | grep cloudflare

# 4. Check certificates
kubectl get certificates -A
# Should show wildcard-shreck-co-uk as Ready: True

# 5. Check Cloudflare Tunnel
kubectl logs -n cloudflared -l app=cloudflared
# Should show "Connection established"

# 6. Test local access
curl -k https://argocd.shreck.co.uk
# (if using self-signed certs temporarily, use -k)

# 7. Test remote access (from outside network)
# Open https://argocd.shreck.co.uk in browser
# Should load via Cloudflare Tunnel
```

## Troubleshooting

### Certificates Not Issuing

**Check cert-manager logs:**
```bash
kubectl logs -n cert-manager -l app=cert-manager
```

**Common issues:**
- Invalid Cloudflare API token → Verify token in Infisical
- DNS not propagated → Wait 5 minutes
- Rate limit → Use `letsencrypt-staging` issuer first

### Tunnel Not Connecting

**Check cloudflared logs:**
```bash
kubectl logs -n cloudflared -l app=cloudflared
```

**Common issues:**
- Invalid tunnel token → Verify token in Infisical
- Network issues → Check cluster internet connectivity
- Tunnel deleted in Cloudflare → Recreate tunnel

### Secrets Not Syncing

**Check Infisical operator:**
```bash
kubectl logs -n infisical-operator-system -l control-plane=controller-manager
```

**Common issues:**
- Invalid credentials → Verify client_id and client_secret
- Project not found → Check project slug in Infisical
- Permission denied → Verify machine identity has read access

## Rollback Procedure

If you need to revert to shreck.io:

```bash
# Checkout previous commit
git checkout 13baae8

# Update Cloudflare back to shreck.io
# Re-run terraform apply
```

**Note:** Not recommended - complete the migration instead!

## Support Resources

- 📖 **INFISICAL-SETUP.md** - Detailed Infisical configuration
- 📖 **CLOUDFLARE-SETUP.md** - Detailed Cloudflare setup
- 📖 **DEPLOYMENT-FLOW.md** - Full deployment automation flow
- 📖 **MIGRATION-SUMMARY.md** - Hardware and architecture overview

## Summary

✅ All configuration files updated to shreck.co.uk
✅ Comprehensive setup guides created
✅ Ready for deployment after completing prerequisites

**Next Steps:**
1. Complete Cloudflare setup (DNS, API token, tunnel)
2. Complete Infisical setup (project, secrets, credentials)
3. Update terraform.tfvars with Infisical credentials
4. Deploy with `terraform apply`

---

**Commit:** 3f6ea23
**Branch:** claude/mayastor-three-workers-config-011CUfp1BrvU2U2ZwMUqpxUZ
**Date:** October 31, 2025
