# ==============================================================================
# main.tf - Single NIC Architecture with Standard Kubernetes Ingress
# ==============================================================================

# ==============================================================================
# ISO Preparation
# ==============================================================================

resource "proxmox_virtual_environment_download_file" "talos_iso" {
  content_type = "iso"
  datastore_id = var.proxmox_iso_storage
  node_name    = var.proxmox_node
  url          = "https://factory.talos.dev/image/${local.schematic_id}/${local.talos_version}/metal-amd64.iso"
  file_name    = local.talos_iso_name

  overwrite           = false
  overwrite_unmanaged = true
}

# ==============================================================================
# Talos Cluster Bootstrap
# ==============================================================================

resource "talos_machine_secrets" "this" {}

# Deploy control plane VM
module "control_plane" {
  source = "./modules/talos-vm"

  vm_name        = var.control_plane.name
  vm_id          = local.vm_ids.control_plane
  target_node    = var.proxmox_node
  cores          = var.control_plane.cores
  memory         = var.control_plane.memory
  disk           = var.control_plane.disk
  ip_address     = var.control_plane.ip
  gateway        = var.prod_gateway
  dns            = var.dns_servers
  network_bridge = var.network_bridge
  storage        = var.proxmox_storage
  iso_storage    = var.proxmox_iso_storage
  talos_version  = local.talos_version
  iso_file       = proxmox_virtual_environment_download_file.talos_iso.id
  gpu_passthrough = false
  gpu_pci_id     = null
  mac_address    = local.mac_addresses.control_plane
  additional_disks = []
}

# Deploy worker VMs with dual NICs
module "workers" {
  source   = "./modules/talos-vm"
  for_each = var.workers

  vm_name        = each.value.name
  vm_id          = local.vm_ids.workers[each.key]
  target_node    = var.proxmox_node
  cores          = each.value.cores
  memory         = each.value.memory
  disk           = each.value.disk
  ip_address     = each.value.ip
  gateway        = var.prod_gateway
  dns            = var.dns_servers
  network_bridge = var.network_bridge
  storage        = var.proxmox_storage
  iso_storage    = var.proxmox_iso_storage
  talos_version  = local.talos_version
  iso_file       = proxmox_virtual_environment_download_file.talos_iso.id
  gpu_passthrough = each.value.gpu
  gpu_pci_id     = each.value.gpu ? each.value.gpu_pci_id : null
  mac_address    = local.mac_addresses.workers[each.key]

  # Dual NIC configuration for Mayastor storage network
  enable_storage_network = true
  storage_bridge         = var.storage_bridge
  storage_mac_address    = local.storage_mac_addresses.workers[each.key]

  # Mayastor disk on helford storage (1TB)
  additional_disks = [{
    size      = each.value.mayastor_disk
    storage   = var.proxmox_mayastor_storage
    interface = "scsi1"
  }]
}

# Deploy Storage Nodes (optional - using workers for Mayastor)
module "storage_nodes" {
  source   = "./modules/talos-vm"
  for_each = var.storage_nodes

  vm_name        = each.value.name
  vm_id          = local.vm_ids.storage[each.key]
  target_node    = var.proxmox_node
  cores          = each.value.cores
  memory         = each.value.memory
  disk           = each.value.disk
  ip_address     = each.value.ip
  gateway        = var.prod_gateway
  dns            = var.dns_servers
  network_bridge = var.network_bridge
  storage        = var.proxmox_storage
  iso_storage    = var.proxmox_iso_storage
  talos_version  = local.talos_version
  iso_file       = proxmox_virtual_environment_download_file.talos_iso.id
  gpu_passthrough = false
  gpu_pci_id     = null
  mac_address    = local.mac_addresses.storage[each.key]

  # Dual NIC configuration for Mayastor storage network
  enable_storage_network = true
  storage_bridge         = var.storage_bridge
  storage_mac_address    = local.storage_mac_addresses.storage[each.key]

  # Mayastor disk on helford storage (1TB)
  additional_disks = [{
    size      = each.value.mayastor_disk
    storage   = var.proxmox_mayastor_storage
    interface = "scsi1"
  }]
}

# Apply Talos to storage nodes
resource "talos_machine_configuration_apply" "storage_nodes" {
  depends_on = [module.storage_nodes]
  for_each   = var.storage_nodes

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.storage_node[each.key].machine_configuration
  node                        = each.value.ip
}

# Label storage nodes for Mayastor
resource "null_resource" "label_storage_nodes" {
  depends_on = [talos_machine_bootstrap.this]
  for_each   = var.storage_nodes

  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG=${path.module}/generated/kubeconfig
      kubectl label nodes ${each.value.name} node-role.kubernetes.io/storage=true --overwrite 2>/dev/null || true
      kubectl label nodes ${each.value.name} openebs.io/engine=mayastor --overwrite 2>/dev/null || true
    EOT
  }
}

# Label worker nodes for Mayastor
resource "null_resource" "label_workers_mayastor" {
  depends_on = [talos_machine_bootstrap.this]
  for_each   = var.workers

  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG=${path.module}/generated/kubeconfig
      kubectl label nodes ${each.value.name} openebs.io/engine=mayastor --overwrite 2>/dev/null || true
    EOT
  }
}



# Deploy TrueNAS VM
#module "truenas" {
#  source = "./modules/truenas-vm"
#
#  vm_name        = var.truenas_vm.name
#  vm_id          = local.vm_ids.truenas
#  target_node    = var.proxmox_node
#  cores          = var.truenas_vm.cores
#  memory         = var.truenas_vm.memory
#  disk           = var.truenas_vm.disk
#  ip_address     = var.truenas_vm.ip
#  gateway        = var.prod_gateway
#  dns            = var.dns_servers
#  network_bridge = var.network_bridge
#  storage        = var.proxmox_truenas_storage
#  iso_storage    = var.proxmox_iso_storage
#  mac_address    = local.mac_addresses.truenas
#}

# ==============================================================================
# Restic Backup LXC Container
# ==============================================================================

# Deploy Restic backup LXC
module "restic_lxc" {
  source = "./modules/restic-lxc"

  vm_name        = "restic-backup"
  vm_id          = var.restic_lxc_vm_id
  target_node    = var.proxmox_node
  cores          = var.restic_lxc_cores
  memory         = var.restic_lxc_memory
  root_disk_size = var.restic_lxc_disk
  ip_address     = var.restic_lxc_ip
  gateway        = var.prod_gateway
  dns_servers    = var.dns_servers
  network_bridge = var.network_bridge
  storage        = var.proxmox_storage

  # Backup and credentials
  root_password      = var.plex_root_password
  ssh_public_keys    = var.ssh_public_keys
  restic_repository  = var.restic_repository
  restic_password    = var.restic_encryption_password
  minio_access_key   = var.minio_access_key
  minio_secret_key   = var.minio_secret_key
}

# Apply Talos configuration to control plane
resource "talos_machine_configuration_apply" "controlplane" {
  depends_on = [module.control_plane]

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = var.control_plane.ip
}

# Wait for control plane to be ready before applying worker configs
resource "time_sleep" "wait_for_controlplane" {
  depends_on      = [talos_machine_configuration_apply.controlplane]
  create_duration = "30s"
}

# Apply Talos configuration to workers
resource "talos_machine_configuration_apply" "worker" {
  depends_on = [
    module.workers,
    time_sleep.wait_for_controlplane
  ]
  for_each = var.workers

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker[each.key].machine_configuration
  node                        = each.value.ip
}

# Bootstrap the cluster
resource "talos_machine_bootstrap" "this" {
  depends_on = [
    talos_machine_configuration_apply.controlplane,
    talos_machine_configuration_apply.worker
  ]

  node                 = var.control_plane.ip
  client_configuration = talos_machine_secrets.this.client_configuration
}

# Save talosconfig
resource "local_file" "talosconfig" {
  content         = data.talos_client_configuration.this.talos_config
  filename        = "${path.module}/generated/talosconfig"
  file_permission = "0600"
}

# Generate kubeconfig
resource "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_machine_bootstrap.this]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.control_plane.ip
}

resource "local_file" "kubeconfig" {
  depends_on = [talos_cluster_kubeconfig.this]

  content         = talos_cluster_kubeconfig.this.kubeconfig_raw
  filename        = "${path.module}/generated/kubeconfig"
  file_permission = "0600"
}

# Wait for cluster API
resource "null_resource" "wait_for_cluster" {
  depends_on = [
    talos_machine_bootstrap.this,
    local_file.kubeconfig
  ]

  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG=${path.module}/generated/kubeconfig
      echo "Waiting for Kubernetes API..."
      timeout 600 bash -c 'until kubectl get --raw /healthz 2>/dev/null; do echo "Waiting..."; sleep 5; done'
      echo "API ready!"
    EOT
  }

  triggers = {
    cluster_id = talos_machine_bootstrap.this.id
  }
}

# ==============================================================================
# Platform Layer: CNI, Load Balancer
# ==============================================================================

# Install Cilium CNI
resource "helm_release" "cilium" {
  depends_on = [null_resource.wait_for_cluster]

  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = "1.18.2"
  namespace  = "kube-system"
  timeout    = 900

  values = [yamlencode({
    ipam = {
      mode = "kubernetes"
    }
    k8sServiceHost       = var.control_plane.ip
    k8sServicePort       = 6443
    kubeProxyReplacement = true

    securityContext = {
      capabilities = {
        ciliumAgent = [
          "CHOWN", "KILL", "NET_ADMIN", "NET_RAW", "IPC_LOCK",
          "SYS_ADMIN", "SYS_RESOURCE", "DAC_OVERRIDE", "FOWNER",
          "SETGID", "SETUID"
        ]
        cleanCiliumState = ["NET_ADMIN", "SYS_ADMIN", "SYS_RESOURCE"]
      }
    }

    cgroup = {
      autoMount = { enabled = false }
      hostRoot  = "/sys/fs/cgroup"
    }

    # Enable Cilium LoadBalancer (L2 announcements)
    l2announcements = {
      enabled = true
      # Ensure Cilium uses the correct interface for L2 announcements
      leaseDuration      = "3s"
      leaseRenewDeadline = "1s"
      leaseRetryPeriod   = "200ms"
    }

    # Specify devices for Cilium to manage
    devices = "ens18"

    # Enable external IPs support
    externalIPs = {
      enabled = true
    }

    hubble = { enabled = false }
  })]
}

# Wait for Cilium to be fully operational
resource "null_resource" "wait_for_cilium" {
  depends_on = [helm_release.cilium]

  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG=${path.module}/generated/kubeconfig
      
      echo "Waiting for Cilium pods to appear..."
      for i in {1..60}; do
        POD_COUNT=$(kubectl get pods -n kube-system -l k8s-app=cilium --no-headers 2>/dev/null | wc -l)
        if [ "$POD_COUNT" -gt 0 ]; then
          echo "Found $POD_COUNT Cilium pods, waiting for ready..."
          kubectl wait --for=condition=ready pod \
            -l k8s-app=cilium \
            -n kube-system \
            --timeout=600s
          echo "✅ Cilium operational"
          exit 0
        fi
        echo "Attempt $i/60: No Cilium pods yet..."
        sleep 5
      done
      
      echo "❌ Cilium pods never appeared"
      exit 1
    EOT
  }
}

# Label worker nodes for Mayastor IO engine
resource "null_resource" "label_mayastor_nodes" {
  depends_on = [null_resource.wait_for_cilium]

  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG=${path.module}/generated/kubeconfig

      echo "Labeling worker nodes for Mayastor IO engine..."
      kubectl label node talos-worker-01 openebs.io/engine=mayastor --overwrite
      kubectl label node talos-worker-02 openebs.io/engine=mayastor --overwrite
      kubectl label node talos-worker-03 openebs.io/engine=mayastor --overwrite

      echo "✓ All worker nodes labeled with openebs.io/engine=mayastor"
    EOT
  }

  # Run on every apply to ensure labels are present
  triggers = {
    always_run = timestamp()
  }
}

# Configure Cilium LoadBalancer IP Pool
resource "kubectl_manifest" "cilium_lb_ippool" {
  depends_on = [null_resource.wait_for_cilium]

  yaml_body = yamlencode({
    apiVersion = "cilium.io/v2alpha1"
    kind       = "CiliumLoadBalancerIPPool"
    metadata = {
      name = "cilium-lb-pool"
    }
    spec = {
      blocks = [
        {
          start = "10.10.0.50"
          stop  = "10.10.0.99"
        }
      ]
    }
  })
}

# Configure Cilium L2 Announcement Policy
resource "kubectl_manifest" "cilium_l2_announcement" {
  depends_on = [kubectl_manifest.cilium_lb_ippool]

  yaml_body = yamlencode({
    apiVersion = "cilium.io/v2alpha1"
    kind       = "CiliumL2AnnouncementPolicy"
    metadata = {
      name = "l2-announcement-policy"
    }
    spec = {
      loadBalancerIPs = true
      # Remove interface restriction - let Cilium auto-detect
      nodeSelector = {
        matchExpressions = [
          {
            key      = "node-role.kubernetes.io/control-plane"
            operator = "DoesNotExist"
          }
        ]
      }
    }
  })
}

# Restart Cilium after L2 policy is created to ensure proper L2 announcement election
resource "null_resource" "restart_cilium_for_l2" {
  depends_on = [kubectl_manifest.cilium_l2_announcement]

  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG=${path.module}/generated/kubeconfig
      echo "Restarting Cilium to apply L2 announcement policies..."
      kubectl rollout restart daemonset cilium -n kube-system
      kubectl rollout status daemonset cilium -n kube-system --timeout=5m
    EOT
  }

  # Force this to run on every apply to ensure L2 announcements are correct
  triggers = {
    always_run = timestamp()
  }
}

# ==============================================================================
# GitOps Controller: ArgoCD
# ==============================================================================

resource "helm_release" "argocd" {
  depends_on = [
    null_resource.wait_for_cilium,
    null_resource.restart_cilium_for_l2
  ]

  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "8.5.8"
  namespace        = "argocd"
  create_namespace = true
  timeout          = 1200
  wait             = false

  values = [
    yamlencode({
      global = {
        securityContext = {
          capabilities = {
            add = ["NET_BIND_SERVICE"]
          }
        }
      }

      server = {
        service = {
          type = "ClusterIP"  # Use Ingress for external access instead of LoadBalancer
        }
        extraArgs = ["--insecure"]
        config = {
          configManagementPlugins = ""
        }
      }

      configs = {
        params = {
          "server.insecure" = true
        }
      }
    })
  ]
}

# ==============================================================================
# ArgoCD Repository Secret via Infisical
# ==============================================================================

resource "kubectl_manifest" "argocd_github_secret" {
  depends_on = [helm_release.argocd, helm_release.infisical]

  yaml_body = yamlencode({
    apiVersion = "secrets.infisical.com/v1alpha1"
    kind       = "InfisicalSecret"
    metadata = {
      name      = "argocd-repo-secret"
      namespace = "argocd"
      labels = {
        "argocd.argoproj.io/secret-type" = "repository"
      }
    }
    spec = {
      hostAPI = "https://app.infisical.com/api"
      authentication = {
        universalAuth = {
          credentialsRef = {
            secretName      = "universal-auth-credentials"
            secretNamespace = "infisical-operator-system"
          }
          secretsScope = {
            projectSlug = "homelab-test-5-ig-k"
            envSlug     = "prod"
            secretsPath = "/infrastructure"
          }
        }
      }
      managedSecretReference = {
        secretName      = "private-repo"
        secretNamespace = "argocd"
        secretType      = "Opaque"
        creationPolicy  = "Owner"
      }
    }
  })
}

# Combine waiting and patching into a single atomic operation
resource "null_resource" "wait_and_patch_secret" {
  depends_on = [kubectl_manifest.argocd_github_secret]

  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG=${path.module}/generated/kubeconfig
      
      echo "Waiting for Infisical to create 'private-repo' secret..."
      for i in {1..60}; do
        if kubectl get secret private-repo -n argocd &>/dev/null; then
          echo "✅ Secret found! Patching with ArgoCD fields..."
          
          kubectl patch secret private-repo -n argocd --type merge -p '{
            "stringData": {
              "type": "git",
              "url": "${var.gitops_repo_url}",
              "username": "git"
            }
          }'
          
          echo "✅ Patch successful!"
          exit 0
        fi
        
        echo "Attempt $i/60: Secret not found yet. Retrying in 2 seconds..."
        sleep 2
      done
      
      echo "❌ Timeout: Timed out waiting for secret 'private-repo' to be created."
      exit 1
    EOT
  }

  triggers = {
    repo_url = var.gitops_repo_url
  }
}

# Deploy App-of-Apps
resource "kubectl_manifest" "argocd_app_of_apps" {
  count      = var.gitops_repo_url != "" ? 1 : 0
  depends_on = [
    null_resource.wait_and_patch_secret,
    null_resource.label_mayastor_nodes
  ]

  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "platform"
      namespace = "argocd"
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.gitops_repo_url
        targetRevision = var.gitops_repo_branch
        path           = "kubernetes/platform"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "argocd"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  })
}
