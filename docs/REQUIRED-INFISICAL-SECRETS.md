# Required Infisical Secrets

This document lists all secrets that must be configured in Infisical for the homelab to function.

## Project: `homelab-test-5-ig-k`
## Environment: `prod`

### Path: `/infrastructure`
| Secret Key | Description | Used By |
|------------|-------------|---------|
| `GITHUB_TOKEN` | GitHub PAT for ArgoCD private repo access and Renovate | ArgoCD, Renovate |

### Path: `/kubernetes`
| Secret Key | Description | Used By |
|------------|-------------|---------|
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token (DNS edit) | cert-manager |
| `TUNNEL_TOKEN` | Cloudflare Tunnel token | cloudflared |

### Path: `/backups`
| Secret Key | Description | Used By |
|------------|-------------|---------|
| `MINIO_ACCESS_KEY` | MinIO access key | Velero |
| `MINIO_SECRET_KEY` | MinIO secret key | Velero |
| `RESTIC_PASSWORD` | Restic encryption password | Restic LXC |
| `PLEX_ROOT_PASSWORD` | Plex LXC root password | Terraform |

### Path: `/media`
| Secret Key | Description | Used By |
|------------|-------------|---------|
| `TRANSMISSION_RPC_USERNAME` | Transmission web UI username | Transmission |
| `TRANSMISSION_RPC_PASSWORD` | Transmission web UI password | Transmission |

### Path: `/apps`
| Secret Key | Description | Used By |
|------------|-------------|---------|
| `PB_ADMIN_EMAIL` | Dashwise/Pocketbase admin email | Dashwise |
| `PB_ADMIN_PASSWORD` | Dashwise/Pocketbase admin password | Dashwise |

## Adding Secrets to Infisical

1. Log in to https://app.infisical.com
2. Select project: `homelab-test-5-ig-k`
3. Select environment: `prod`
4. Navigate to the appropriate path
5. Click "Add Secret"
6. Enter the key and value
7. Save

Kubernetes will sync secrets automatically via InfisicalSecret CRDs.
