# Home Assistant Lovelace Dashboard

This directory contains a YAML-based Lovelace dashboard configuration for Home Assistant.

## What Changed

I've converted your UI-managed Lovelace dashboard to a YAML-based configuration with the following benefits:

- **Version Control**: Dashboard configuration is now in Git
- **Easier Management**: Edit dashboards in YAML instead of the UI
- **Consistency**: Configuration can be deployed consistently across environments
- **Backup**: Dashboard config is automatically backed up with your code

## Files

- `lovelace.yaml` - Standalone Lovelace configuration file (reference)
- `lovelace-configmap.yaml` - Kubernetes ConfigMap containing the dashboard
- `deployment.yaml` - Updated to mount the ConfigMap
- `kustomization.yaml` - Updated to include the ConfigMap resource

## Dashboard Views

Your dashboard includes:

1. **Home** - Main view with all room lighting controls
   - Bedroom lights
   - Kitchen/Diner lights
   - Living Room lights
   - Downstairs lighting
   - Play Room
   - Kids Rooms (Vienna & Albie)
   - Upstairs misc lights
   - Utilities (Macerator)

2. **Christmas Switches** - Seasonal lighting controls
   - Christmas trees (Hall, Living Room, Kitchen)
   - Reindeer
   - Vienna's Christmas lights
   - Bedroom curtain

3. **Multi-Sockets** - Power socket controls
   - Garage sockets (2 groups)
   - Living Room sockets
   - Study sockets (2 groups)
   - Vienna's sockets

4. **Home Mon** - Weather monitoring
   - Weather forecast card

5. **Test** - Test buttons for specific lights

## Deployment

### Option 1: Deploy via ArgoCD (Recommended)

ArgoCD will automatically sync the changes:

```bash
# Sync the homeassistant application
kubectl patch application homeassistant -n argocd --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'

# Wait for sync to complete
argocd app wait homeassistant
```

### Option 2: Manual Deployment

```bash
# Set kubeconfig
export KUBECONFIG=/root/homelab-test/infrastructure/terraform/generated/kubeconfig

# Apply the ConfigMap
kubectl apply -f lovelace-configmap.yaml

# Restart the Home Assistant pod to pick up the new configuration
kubectl rollout restart deployment/homeassistant -n apps

# Wait for rollout to complete
kubectl rollout status deployment/homeassistant -n apps
```

## Enabling YAML Mode

After deployment, you need to enable YAML mode in Home Assistant:

1. Access Home Assistant UI
2. Go to **Settings** → **Dashboards**
3. Click on the three dots menu on your dashboard
4. Select **Edit Dashboard**
5. Click on the three dots menu again
6. Select **Raw configuration editor**
7. You should see a message about YAML mode

Alternatively, add this to your Home Assistant `configuration.yaml`:

```yaml
lovelace:
  mode: yaml
  resources: []
```

Then restart Home Assistant for the changes to take effect.

## Editing the Dashboard

To make changes to your dashboard:

1. Edit `lovelace-configmap.yaml` in this directory
2. Commit and push your changes
3. ArgoCD will automatically sync the changes
4. Restart the Home Assistant pod to reload the configuration

## Reverting to UI Mode

If you want to go back to UI-managed dashboards:

1. Remove the `lovelace-config` volume mount from `deployment.yaml`
2. Remove `lovelace-configmap.yaml` from `kustomization.yaml`
3. Delete the ConfigMap: `kubectl delete configmap homeassistant-lovelace -n apps`
4. In Home Assistant UI, re-enable UI mode in dashboard settings

## Troubleshooting

### Dashboard not updating
- Restart the Home Assistant pod: `kubectl rollout restart deployment/homeassistant -n apps`
- Check ConfigMap is mounted: `kubectl exec -n apps homeassistant-<pod> -- cat /config/ui-lovelace.yaml`

### Entities not showing
- Verify entity IDs match your actual entities in Home Assistant
- Check Home Assistant logs: `kubectl logs -n apps deployment/homeassistant`

### YAML syntax errors
- Validate YAML syntax before deploying
- Check Home Assistant logs for specific error messages
