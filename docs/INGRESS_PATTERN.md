# Standard Ingress Pattern

This document defines the standard Kubernetes Ingress pattern used across all applications in the homelab cluster.

## Overview

All applications use standard Kubernetes `Ingress` resources with Traefik as the ingress controller. TLS termination is handled by Traefik using certificates from cert-manager.

## Standard Ingress Template

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: <app-name>
  namespace: <namespace>
  annotations:
    traefik.ingress.kubernetes.io/router.tls: "true"
    # Optional: Homepage integration
    gethomepage.dev/enabled: "true"
    gethomepage.dev/name: "<Display Name>"
    gethomepage.dev/description: "<App Description>"
    gethomepage.dev/group: "<Group Name>"
    gethomepage.dev/icon: "<icon-name>.png"
    gethomepage.dev/pod-selector: "app=<app-name>"
    # Optional: Homepage widget integration
    gethomepage.dev/widget.type: "<widget-type>"
    gethomepage.dev/widget.url: "http://<service>.<namespace>.svc.cluster.local:<port>"
    gethomepage.dev/widget.key: "{{HOMEPAGE_VAR_<APP>_API_KEY}}"
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - <app-name>.shreck.co.uk
      secretName: shreck-co-uk-tls
  rules:
    - host: <app-name>.shreck.co.uk
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: <service-name>
                port:
                  number: <port>
```

## Key Components

### Required Fields

1. **ingressClassName**: Always set to `traefik`
2. **TLS Configuration**:
   - Hosts must use `*.shreck.co.uk` domain
   - secretName must be `shreck-co-uk-tls` (wildcard cert from cert-manager)
3. **Traefik TLS Annotation**: `traefik.ingress.kubernetes.io/router.tls: "true"`

### Optional: Homepage Integration

Applications can integrate with Homepage dashboard using annotations:

**Basic Integration:**
- `gethomepage.dev/enabled: "true"` - Enable homepage integration
- `gethomepage.dev/name` - Display name
- `gethomepage.dev/description` - Short description
- `gethomepage.dev/group` - Group category (e.g., "Media", "Apps")
- `gethomepage.dev/icon` - Icon filename
- `gethomepage.dev/pod-selector` - Label selector for pod discovery

**Widget Integration:**
For applications with API support (Sonarr, Radarr, etc.):
- `gethomepage.dev/widget.type` - Widget type (sonarr, radarr, overseerr, etc.)
- `gethomepage.dev/widget.url` - Internal cluster URL
- `gethomepage.dev/widget.key` - API key from Infisical (use template variable)

## Domain Structure

All applications follow the pattern: `<app-name>.shreck.co.uk`

Examples:
- `sonarr.shreck.co.uk`
- `radarr.shreck.co.uk`
- `homepage.shreck.co.uk`
- `argocd.shreck.co.uk`

## TLS/SSL Certificates

- **Certificate**: Wildcard certificate `*.shreck.co.uk` managed by cert-manager
- **Secret**: `shreck-co-uk-tls` (automatically created by cert-manager)
- **Issuer**: Cloudflare DNS challenge via Let's Encrypt

## External Access

External access is provided through:
- **Cloudflare Tunnel** (for external access without exposing ports)
- **Traefik LoadBalancer** (Cilium L2 announcements on 10.10.0.150)

## Best Practices

1. **Always use the standard template** - Copy from existing ingresses
2. **Use consistent naming** - Ingress name should match application name
3. **Include Homepage annotations** - Makes applications discoverable
4. **Use cluster-local URLs for widgets** - Avoid external routing overhead
5. **Store API keys in Infisical** - Reference with template variables

## Examples

### Simple Application (No Widget)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: filebrowser
  namespace: apps
  annotations:
    traefik.ingress.kubernetes.io/router.tls: "true"
    gethomepage.dev/enabled: "true"
    gethomepage.dev/name: "File Browser"
    gethomepage.dev/description: "Web-based file manager"
    gethomepage.dev/group: "Apps"
    gethomepage.dev/icon: "filebrowser.png"
    gethomepage.dev/pod-selector: "app=filebrowser"
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - filebrowser.shreck.co.uk
      secretName: shreck-co-uk-tls
  rules:
    - host: filebrowser.shreck.co.uk
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: filebrowser
                port:
                  number: 80
```

### Application with Widget Integration

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: radarr
  namespace: media
  annotations:
    traefik.ingress.kubernetes.io/router.tls: "true"
    gethomepage.dev/enabled: "true"
    gethomepage.dev/name: "Radarr"
    gethomepage.dev/description: "Movie collection manager"
    gethomepage.dev/group: "Media"
    gethomepage.dev/icon: "radarr.png"
    gethomepage.dev/pod-selector: "app=radarr"
    gethomepage.dev/widget.type: "radarr"
    gethomepage.dev/widget.url: "http://radarr.media.svc.cluster.local:7878"
    gethomepage.dev/widget.key: "{{HOMEPAGE_VAR_RADARR_API_KEY}}"
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - radarr.shreck.co.uk
      secretName: shreck-co-uk-tls
  rules:
    - host: radarr.shreck.co.uk
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: radarr
                port:
                  number: 7878
```

## Troubleshooting

### Ingress Not Working

1. Check Traefik is running: `kubectl get pods -n traefik`
2. Verify certificate exists: `kubectl get secret shreck-co-uk-tls -n <namespace>`
3. Check ingress status: `kubectl describe ingress <name> -n <namespace>`
4. View Traefik logs: `kubectl logs -n traefik -l app.kubernetes.io/name=traefik`

### TLS Certificate Issues

1. Check cert-manager logs: `kubectl logs -n cert-manager -l app=cert-manager`
2. Verify certificate status: `kubectl get certificate -n cert-manager`
3. Check ClusterIssuer: `kubectl describe clusterissuer letsencrypt-prod`

### Homepage Not Showing Application

1. Verify annotations are correct (no typos)
2. Check pod selector matches: `kubectl get pods -n <namespace> -l app=<app-name>`
3. Restart Homepage: `kubectl rollout restart deployment homepage -n apps`

## Migration Notes

All ingresses in this cluster follow this standard pattern. When adding new applications:

1. Copy an existing ingress.yaml from a similar application
2. Update names, namespace, and service details
3. Adjust Homepage annotations as needed
4. Ensure the application has a corresponding ArgoCD Application manifest
