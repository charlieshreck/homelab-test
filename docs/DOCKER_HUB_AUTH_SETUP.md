# Docker Hub Authentication Setup

This document explains how to configure Docker Hub authentication in your Talos cluster to avoid rate limiting.

## Problem

Docker Hub limits anonymous pulls to **100 per 6 hours** per IP address. This causes `ImagePullBackOff` errors:

```
429 Too Many Requests
toomanyrequests: You have reached your unauthenticated pull rate limit.
```

## Solution

Add Docker Hub authentication to increase the limit to **200 pulls per 6 hours**.

## Prerequisites

- Docker Hub account (free at https://hub.docker.com/signup)
- Access to your Terraform workspace

## Setup Instructions

### 1. Add Credentials to terraform.tfvars

Edit `infrastructure/terraform/terraform.tfvars` and add:

```hcl
# Docker Hub Configuration (to avoid rate limiting)
dockerhub_username = "your-docker-hub-username"
dockerhub_password = "your-docker-hub-password-or-token"
```

**Note:** The credentials are already configured in the current terraform.tfvars file.

### 2. Apply Terraform Changes

```bash
cd infrastructure/terraform
terraform plan    # Review changes
terraform apply -auto-approve
```

This will update the Talos machine configurations with registry authentication.

### 3. Reboot Nodes

Talos needs to be rebooted for the registry configuration to take effect:

```bash
# Using talosctl
talosctl reboot -n 10.10.0.20  # Control plane
talosctl reboot -n 10.10.0.21,10.10.0.22,10.10.0.23  # Workers

# Or reboot one at a time for zero-downtime:
talosctl reboot -n 10.10.0.21
# Wait for node to come back up
talosctl reboot -n 10.10.0.22
# Wait for node to come back up
talosctl reboot -n 10.10.0.23
```

### 4. Verify

After nodes reboot, verify images can be pulled:

```bash
# Check if pods start successfully
kubectl get pods -A

# Check specific pod events
kubectl describe pod -n mayastor mayastor-etcd-0 | tail -30

# Should no longer see "429 Too Many Requests" errors
```

## Alternative: Wait for Rate Limit Reset

If you don't want to set up authentication immediately, you can wait for the rate limit to reset:

- Rate limits work on a **rolling 6-hour window**
- Could take anywhere from 30 minutes to 6 hours
- Check periodically with: `kubectl delete pod -n mayastor mayastor-etcd-0`

## Security Note

The `terraform.tfvars` file is in `.gitignore` to prevent committing sensitive credentials. However, if it was previously tracked in git, you may need to:

```bash
# Remove from git tracking (keeps local file)
git rm --cached infrastructure/terraform/terraform.tfvars

# Verify it's no longer tracked
git status
```

## Troubleshooting

### Images still failing to pull after setup

1. Verify credentials are correct in terraform.tfvars
2. Check nodes picked up the config: `talosctl get machineconfig -n 10.10.0.21`
3. Ensure nodes were rebooted after terraform apply
4. Check containerd logs: `talosctl logs -n 10.10.0.21 -k | grep containerd`

### How to check current rate limit status

Docker Hub doesn't provide an API to check your current usage. The best approach is to try pulling an image and see if it succeeds.

## References

- [Docker Hub Rate Limiting](https://docs.docker.com/docker-hub/download-rate-limit/)
- [Talos Registry Configuration](https://www.talos.dev/v1.11/talos-guides/configuration/pull-through-cache/)
