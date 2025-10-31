# Cloudflare Setup Guide

This guide walks through configuring Cloudflare for your homelab, including DNS management, API tokens for cert-manager, and Cloudflare Tunnel for secure remote access.

## Overview

**What Cloudflare Provides:**
- **DNS Management**: Authoritative DNS for shreck.co.uk
- **TLS Certificates**: Let's Encrypt via DNS-01 challenge (cert-manager)
- **Zero Trust Tunnel**: Secure remote access without port forwarding
- **DDoS Protection**: Free tier includes basic protection
- **CDN**: Optional caching for public services

## Prerequisites

- Domain registered and managed by Cloudflare (shreck.co.uk)
- Cloudflare account: [https://dash.cloudflare.com/sign-up](https://dash.cloudflare.com/sign-up)

## Part 1: DNS Configuration

### Step 1: Add Domain to Cloudflare

If shreck.co.uk is not already in Cloudflare:

1. Log in to [Cloudflare Dashboard](https://dash.cloudflare.com)

2. Click **"Add a Site"**

3. Enter your domain: `shreck.co.uk`

4. Select **Free Plan** (sufficient for homelab)

5. Cloudflare will scan existing DNS records

6. Update nameservers at your domain registrar:
   ```
   NS1: ava.ns.cloudflare.com
   NS2: mark.ns.cloudflare.com
   ```
   (Your specific nameservers will be shown in Cloudflare)

7. Wait for DNS propagation (5 minutes to 48 hours)

8. Verify: `dig NS shreck.co.uk` should show Cloudflare nameservers

### Step 2: Configure DNS Records

Navigate to **DNS** → **Records** and add:

#### A Records (for local network access)

| Type | Name | Content | Proxy | TTL |
|------|------|---------|-------|-----|
| A | @ | 10.10.0.80 | ❌ DNS only | Auto |
| A | * | 10.10.0.80 | ❌ DNS only | Auto |
| A | argocd | 10.10.0.80 | ❌ DNS only | Auto |
| A | sonarr | 10.10.0.80 | ❌ DNS only | Auto |
| A | radarr | 10.10.0.80 | ❌ DNS only | Auto |
| A | prowlarr | 10.10.0.80 | ❌ DNS only | Auto |
| A | overseerr | 10.10.0.80 | ❌ DNS only | Auto |
| A | transmission | 10.10.0.80 | ❌ DNS only | Auto |

**Important:**
- Use **DNS only** (gray cloud) for local IPs
- `10.10.0.80` is Traefik's LoadBalancer IP (from Cilium)
- Wildcard `*` catches all subdomains not explicitly defined

#### CNAME Records (for Cloudflare Tunnel)

Add these later after creating the tunnel (see Part 3).

### Step 3: SSL/TLS Settings

1. Navigate to **SSL/TLS** → **Overview**

2. Set encryption mode:
   - **Full (strict)** if you have valid certs on Traefik
   - **Full** if using self-signed certs temporarily
   - **Flexible** not recommended (insecure)

3. Navigate to **SSL/TLS** → **Edge Certificates**

4. Enable these settings:
   - ✅ **Always Use HTTPS**: Redirect HTTP to HTTPS
   - ✅ **Automatic HTTPS Rewrites**: Fix mixed content
   - ✅ **Minimum TLS Version**: TLS 1.2 or higher
   - ❌ **TLS 1.3**: Optional (enable for better security)

## Part 2: API Token for cert-manager

cert-manager needs a Cloudflare API token to complete DNS-01 challenges for Let's Encrypt certificates.

### Step 1: Create API Token

1. Navigate to **Profile** (top right) → **API Tokens**

2. Click **"Create Token"**

3. Use the **"Edit zone DNS"** template

4. Configure permissions:
   ```
   Zone - DNS - Edit
   Zone - Zone - Read
   ```

5. Set zone resources:
   - **Include** → **Specific zone** → `shreck.co.uk`

6. Set client IP restrictions (optional but recommended):
   - Add your homelab's public IP
   - Or leave blank for any IP

7. Set TTL (optional):
   - Leave blank for no expiration
   - Or set to 1 year and rotate annually

8. Click **"Continue to summary"**

9. Review and click **"Create Token"**

10. **COPY THE TOKEN IMMEDIATELY** - it won't be shown again!
    ```
    Example: qwertyuiop1234567890asdfghjklzxcvbnm
    ```

### Step 2: Store Token in Infisical

1. Log in to [Infisical](https://app.infisical.com)

2. Navigate to your `homelab-prod` project

3. Add secret at path `/`:
   - **Key**: `CLOUDFLARE_API_TOKEN`
   - **Value**: `<paste your token>`

4. Add email at path `/`:
   - **Key**: `CLOUDFLARE_EMAIL`
   - **Value**: `charlieshreck@gmail.com`

5. Click **"Save"**

### Step 3: Verify Token (Optional)

Test the token with curl:

```bash
# Replace YOUR_TOKEN with your actual token
curl -X GET "https://api.cloudflare.com/client/v4/zones" \
     -H "Authorization: Bearer YOUR_TOKEN" \
     -H "Content-Type: application/json"

# Should return JSON with your zone information
# Look for "shreck.co.uk" in the results
```

## Part 3: Cloudflare Tunnel Setup

Cloudflare Tunnel provides secure remote access to your homelab without opening firewall ports.

### What is Cloudflare Tunnel?

```
Internet
    ↓
Cloudflare Network (global CDN)
    ↓
Cloudflare Tunnel (encrypted connection)
    ↓
cloudflared pod (in your cluster)
    ↓
Traefik Ingress Controller
    ↓
Your Applications
```

**Benefits:**
- No port forwarding required
- No public IP needed
- DDoS protection included
- Zero trust access controls

### Step 1: Create Tunnel

1. Navigate to **Zero Trust** dashboard:
   - [https://one.dash.cloudflare.com](https://one.dash.cloudflare.com)

2. Go to **Networks** → **Tunnels**

3. Click **"Create a tunnel"**

4. Select **"Cloudflared"**

5. Name your tunnel: `homelab-shreck-co-uk`

6. Click **"Save tunnel"**

### Step 2: Get Tunnel Token

1. After creating the tunnel, you'll see a token:
   ```
   eyJhIjoiYWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXowMTIzNDU2Nzg5IiwidCI6Im15dHVubmVsaWQiLCJzIjoibXlzZWNyZXQifQ==
   ```

2. **COPY THIS TOKEN** - you'll need it for Kubernetes

3. Click **"Next"**

### Step 3: Configure Routes

Add public hostnames that route through the tunnel:

| Public Hostname | Service | Path |
|---|---|---|
| argocd.shreck.co.uk | https://traefik.traefik.svc.cluster.local | / |
| sonarr.shreck.co.uk | https://traefik.traefik.svc.cluster.local | / |
| radarr.shreck.co.uk | https://traefik.traefik.svc.cluster.local | / |
| prowlarr.shreck.co.uk | https://traefik.traefik.svc.cluster.local | / |
| overseerr.shreck.co.uk | https://traefik.traefik.svc.cluster.local | / |

**Settings for each route:**
- **Type**: HTTPS
- **URL**: `https://traefik.traefik.svc.cluster.local`
- **TLS verification**: Disable (unless you have valid internal certs)
- **HTTP Host Header**: `<service>.shreck.co.uk`

**How it works:**
- Cloudflare Tunnel sends traffic to Traefik
- Traefik inspects `Host` header
- Routes to appropriate backend service via Ingress rules

### Step 4: Store Tunnel Token in Infisical

1. In Infisical, navigate to your `homelab-prod` project

2. Create a new folder/path: `/cloudflared`

3. Add secret:
   - **Key**: `TUNNEL_TOKEN`
   - **Value**: `<paste your tunnel token>`

4. Click **"Save"**

### Step 5: Verify Tunnel Deployment

After running `terraform apply`, cloudflared will be deployed.

```bash
# Check cloudflared pod
kubectl get pods -n cloudflared

# Check logs
kubectl logs -n cloudflared -l app=cloudflared

# Expected output:
# "Connection established" - Tunnel is connected
# "Registered tunnel connection" - Routes are active
```

### Step 6: Test Remote Access

1. From outside your network (mobile data or different WiFi):
   ```
   https://argocd.shreck.co.uk
   ```

2. Should load ArgoCD UI without VPN

3. Verify Cloudflare is proxying:
   ```bash
   curl -I https://argocd.shreck.co.uk
   # Look for "cf-ray" header - indicates Cloudflare proxy
   ```

## Part 4: Security Best Practices

### API Token Security

1. **Rotate regularly**: Create new tokens every 90-180 days

2. **Use minimal permissions**:
   - Only `Edit zone DNS` for cert-manager
   - Never use Global API Key

3. **Monitor usage**:
   - Check Cloudflare Audit Logs for unusual activity
   - Set up alerts for failed auth attempts

4. **Revoke compromised tokens immediately**:
   - Go to Profile → API Tokens
   - Click "Roll" or "Revoke"

### Tunnel Security

1. **Enable Access policies** (Cloudflare Zero Trust):
   - Require authentication for sensitive services
   - Use email-based auth or SSO
   - Whitelist specific email domains

2. **Example Access Policy**:
   ```
   Application: argocd.shreck.co.uk
   Policy: Allow emails ending in @gmail.com
   Action: Require Google OAuth
   ```

3. **Monitor tunnel traffic**:
   - Check Zero Trust analytics
   - Review connection logs

### DNS Security

1. **Enable DNSSEC**:
   - Navigate to DNS → Settings
   - Enable DNSSEC
   - Add DS records to your registrar

2. **Use CAA records** (Certificate Authority Authorization):
   ```
   Type: CAA
   Name: @
   Tag: issue
   Value: letsencrypt.org
   ```
   This prevents other CAs from issuing certs for your domain

3. **Enable Rate Limiting** (optional):
   - Free tier has basic DDoS protection
   - Paid plans offer advanced rate limiting

## Part 5: Troubleshooting

### cert-manager Certificate Issues

**Symptoms:**
```bash
kubectl get certificates -A
# Shows "False" in READY column
```

**Solution:**
```bash
# Check certificate status
kubectl describe certificate -n traefik wildcard-shreck-co-uk

# Common issues:
# 1. Invalid API token → Verify token in Infisical
# 2. DNS propagation → Wait 2-5 minutes
# 3. Rate limit → Use staging issuer first (letsencrypt-staging)
# 4. Wrong zone → Verify domain in Cloudflare matches shreck.co.uk
```

**Test DNS-01 challenge manually:**
```bash
# Check if cert-manager can create TXT records
dig _acme-challenge.shreck.co.uk TXT

# Should show TXT record created by cert-manager
```

### Cloudflare Tunnel Not Connecting

**Symptoms:**
```bash
kubectl logs -n cloudflared -l app=cloudflared
# Shows "Failed to connect" or "Authentication failed"
```

**Solution:**
```bash
# 1. Verify tunnel token
kubectl get secret -n cloudflared cloudflared-token -o jsonpath='{.data.token}' | base64 -d

# 2. Check tunnel status in Cloudflare
# Navigate to Zero Trust → Networks → Tunnels
# Should show "Healthy" status

# 3. Restart cloudflared
kubectl rollout restart deployment/cloudflared -n cloudflared
```

### DNS Resolution Issues

**Symptoms:**
- Domain doesn't resolve
- Resolves to wrong IP

**Solution:**
```bash
# Check DNS propagation
dig shreck.co.uk +short
# Should return 10.10.0.80 (if querying from local network)

# Check from external resolver
dig @1.1.1.1 shreck.co.uk +short
# Should return Cloudflare proxy IP (if proxied)

# Check nameservers
dig NS shreck.co.uk +short
# Should show Cloudflare nameservers
```

## Part 6: Advanced Configuration

### Split-Horizon DNS (Optional)

Use different IPs for internal vs. external access:

**Internal (via local DNS server):**
- `argocd.shreck.co.uk` → `10.10.0.80` (direct to Traefik)

**External (via Cloudflare):**
- `argocd.shreck.co.uk` → Cloudflare Tunnel

**Implementation:**
1. Set up local DNS server (Pi-hole, AdGuard Home, etc.)
2. Add local DNS records for `*.shreck.co.uk` → `10.10.0.80`
3. Local clients use local DNS
4. External clients use Cloudflare DNS → Tunnel

**Benefits:**
- Faster local access (no tunnel overhead)
- Works even if internet is down
- Reduced Cloudflare bandwidth usage

### Access Policies (Zero Trust)

Require authentication for sensitive services:

1. Go to **Zero Trust** → **Access** → **Applications**

2. Click **"Add an application"**

3. Select **"Self-hosted"**

4. Configure:
   - **Name**: ArgoCD
   - **Domain**: `argocd.shreck.co.uk`
   - **Path**: `/`

5. Add policy:
   - **Name**: Allow Gmail users
   - **Action**: Allow
   - **Rule**: Emails ending in `@gmail.com`
   - **Identity provider**: Google

6. Click **"Save"**

7. Now accessing `argocd.shreck.co.uk` requires Google login

## Part 7: Monitoring and Maintenance

### Cloudflare Analytics

1. Navigate to **Analytics & Logs** → **Traffic**

2. Monitor:
   - Requests per second
   - Bandwidth usage
   - HTTP status codes (look for 5xx errors)
   - Top endpoints

### Certificate Expiry

```bash
# Check certificate expiry
kubectl get certificates -A

# Cert-manager auto-renews 30 days before expiry
# Check cert-manager logs for renewal attempts
kubectl logs -n cert-manager -l app=cert-manager
```

### API Token Rotation

Set calendar reminder to rotate tokens every 6 months:

1. Create new API token
2. Update Infisical secret
3. Wait for Infisical operator to sync (~60 seconds)
4. Verify cert-manager still works
5. Revoke old token in Cloudflare

## Summary

✅ **DNS configured** for shreck.co.uk
✅ **API token created** for cert-manager
✅ **Tunnel created** for remote access
✅ **Secrets stored** in Infisical
✅ **Security hardened** with best practices

## Next Steps

1. ✅ Complete Cloudflare setup
2. ✅ Complete Infisical setup (see INFISICAL-SETUP.md)
3. → Deploy homelab cluster with Terraform
4. → Verify certificates are issued
5. → Test remote access via tunnel

## Additional Resources

- [Cloudflare DNS Documentation](https://developers.cloudflare.com/dns/)
- [Cloudflare Tunnel Guide](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [cert-manager Cloudflare DNS01](https://cert-manager.io/docs/configuration/acme/dns01/cloudflare/)
- [Cloudflare API Documentation](https://developers.cloudflare.com/api/)

---

**Last Updated:** October 31, 2025
**Domain:** shreck.co.uk
