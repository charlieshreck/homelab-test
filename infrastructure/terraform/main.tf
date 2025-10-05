# Main orchestration file - focuses on resource creation and dependencies
# Configuration details moved to: providers.tf, locals.tf, data.tf, variables.tf, outputs.tf

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

  vm_name              = var.control_plane.name
  vm_id                = local.vm_ids.control_plane
  target_node          = var.proxmox_node
  cores                = var.control_plane.cores
  memory               = var.control_plane.memory
  disk                 = var.control_plane.disk
  ip_address           = var.control_plane.ip
  gateway              = var.prod_gateway
  dns                  = var.dns_servers
  network_bridge       = var.network_bridge
  storage              = var.proxmox_storage
  iso_storage          = var.proxmox_iso_storage
  talos_version        = local.talos_version
  iso_file             = proxmox_virtual_environment_download_file.talos_iso.id
  gpu_passthrough      = false
  gpu_pci_id           = null
  mac_address          = local.mac_addresses.control_plane
  internal_mac_address = local.internal_mac_addresses.control_plane
  additional_disks     = []
}

# Deploy worker VMs
module "workers" {
  source = "./modules/talos-vm"
  count  = length(var.workers)

  vm_name              = var.workers[count.index].name
  vm_id                = local.vm_ids.workers[count.index]
  target_node          = var.proxmox_node
  cores                = var.workers[count.index].cores
  memory               = var.workers[count.index].memory
  disk                 = var.workers[count.index].disk
  ip_address           = var.workers[count.index].ip
  gateway              = var.prod_gateway
  dns                  = var.dns_servers
  network_bridge       = var.network_bridge
  storage              = var.proxmox_storage
  iso_storage          = var.proxmox_iso_storage
  talos_version        = local.talos_version
  iso_file             = proxmox_virtual_environment_download_file.talos_iso.id
  gpu_passthrough      = var.workers[count.index].gpu
  gpu_pci_id           = var.workers[count.index].gpu ? var.workers[count.index].gpu_pci_id : null
  mac_address          = local.mac_addresses.workers[count.index]
  internal_mac_address = local.internal_mac_addresses.workers[count.index]

  additional_disks = [{
    size      = var.workers[count.index].longhorn_disk
    storage   = var.proxmox_longhorn_storage
    interface = "scsi1"
  }]
}

# Deploy TrueNAS VM
module "truenas" {
  source = "./modules/truenas-vm"

  vm_name        = var.truenas_vm.name
  vm_id          = local.vm_ids.truenas
  target_node    = var.proxmox_node
  cores          = var.truenas_vm.cores
  memory         = var.truenas_vm.memory
  disk           = var.truenas_vm.disk
  ip_address     = var.truenas_vm.ip
  gateway        = var.prod_gateway
  dns            = var.dns_servers
  network_bridge = var.network_bridge
  storage        = var.proxmox_truenas_storage
  iso_storage    = var.proxmox_iso_storage
  mac_address    = local.mac_addresses.truenas
}

# Apply Talos configuration to control plane
resource "talos_machine_configuration_apply" "controlplane" {
  depends_on = [module.control_plane]

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = var.control_plane.ip
}

# Apply Talos configuration to workers
resource "talos_machine_configuration_apply" "worker" {
  depends_on = [module.workers]
  count      = length(var.workers)

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker[count.index].machine_configuration
  node                        = var.workers[count.index].ip
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

# Generate kubeconfig
resource "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_machine_bootstrap.this]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.control_plane.ip
}

# Wait for cluster to be healthy
resource "null_resource" "wait_for_cluster" {
  depends_on = [
    talos_machine_bootstrap.this,
    talos_cluster_kubeconfig.this
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
# Platform Layer: CNI, Load Balancer, Storage, Secrets
# These are infrastructure components that ArgoCD depends on
# ==============================================================================

# Install Cilium CNI
resource "helm_release" "cilium" {
  depends_on = [null_resource.wait_for_cluster]

  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = "1.18.2"
  namespace  = "kube-system"

  timeout       = 900
  wait          = true
  wait_for_jobs = true

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

    hubble = { enabled = false }
  })]
}

resource "null_resource" "wait_for_cilium" {
  depends_on = [helm_release.cilium]

  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG=${path.module}/generated/kubeconfig
      kubectl wait --for=condition=ready pod -l k8s-app=cilium -n kube-system --timeout=600s
      kubectl wait --for=condition=ready nodes --all --timeout=600s
    EOT
  }
}

# Install MetalLB for LoadBalancer services
resource "helm_release" "metallb" {
  depends_on = [null_resource.wait_for_cilium]

  name             = "metallb"
  repository       = "https://metallb.github.io/metallb"
  chart            = "metallb"
  version          = "0.15.2"
  namespace        = "metallb-system"
  create_namespace = true

  timeout = 600
  wait    = false
}

resource "null_resource" "wait_for_metallb" {
  depends_on = [helm_release.metallb]

  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG=${path.module}/generated/kubeconfig
      echo "Waiting for MetalLB pods to be ready..."
      kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=metallb -n metallb-system --timeout=300s
      sleep 10
    EOT
  }
}

resource "kubectl_manifest" "metallb_ippool" {
  depends_on = [null_resource.wait_for_metallb]

  yaml_body = yamlencode({
    apiVersion = "metallb.io/v1beta1"
    kind       = "IPAddressPool"
    metadata = {
      name      = "production-pool"
      namespace = "metallb-system"
    }
    spec = {
      addresses = var.metallb_ip_range
    }
  })
}

resource "kubectl_manifest" "metallb_l2advert" {
  depends_on = [kubectl_manifest.metallb_ippool]

  yaml_body = yamlencode({
    apiVersion = "metallb.io/v1beta1"
    kind       = "L2Advertisement"
    metadata = {
      name      = "l2-advert"
      namespace = "metallb-system"
    }
    spec = {
      ipAddressPools = ["production-pool"]
    }
  })
}

# Install Longhorn for persistent storage
# Kept in Terraform due to Talos-specific disk configuration dependencies
resource "kubernetes_namespace" "longhorn_system" {
  depends_on = [null_resource.wait_for_cilium]
  
  metadata {
    name = "longhorn-system"
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
    }
  }
}

resource "helm_release" "longhorn" {
  count = var.longhorn_managed_by_argocd ? 0 : 1
  
  depends_on = [
    kubernetes_namespace.longhorn_system,
    null_resource.wait_for_metallb
  ]
  
  name             = "longhorn"
  repository       = "https://charts.longhorn.io"
  chart            = "longhorn"
  version          = "1.10.0"
  namespace        = "longhorn-system"
  create_namespace = false
  timeout          = 1200

  values = [
    yamlencode({
      kubernetesDistro = "k8s"
      
      service = {
        ui = {
          type = "LoadBalancer"
          annotations = {
            "metallb.universe.tf/loadBalancerIPs" = "10.30.0.70"
          }
        }
      }

      defaultSettings = {
        defaultDataPath = "/var/lib/longhorn"
        defaultReplicaCount = "2"
        storageMinimalAvailablePercentage = "10"
      }
      
      persistence = {
        defaultClass = true
        defaultClassReplicaCount = 2
        reclaimPolicy = "Retain"
      }
      
      csi = {
        kubeletRootDir          = "/var/lib/kubelet"
        attacherReplicaCount    = "3"
        provisionerReplicaCount = "3"
        resizerReplicaCount     = "3"
        snapshotterReplicaCount = "3"
      }

      longhornManager = {
        tolerations = [
          {
            key      = "node-role.kubernetes.io/control-plane"
            operator = "Exists"
            effect   = "NoSchedule"
          }
        ]
      }
      longhornDriver = {
        tolerations = [
          {
            key      = "node-role.kubernetes.io/control-plane"
            operator = "Exists"
            effect   = "NoSchedule"
          }
        ]
      }
    })
  ]
  
  set = [
    {
      name  = "enablePSP"
      value = "false"
    }
  ]
}

# ==============================================================================
# Secrets Management: Vault + External Secrets Operator
# Deployed before ArgoCD so secrets are available for all applications
# ==============================================================================

# Vault deployment is in vault.tf
# External Secrets Operator is in external-secrets.tf

# ==============================================================================
# GitOps Controller: ArgoCD
# ArgoCD manages all application-layer resources from this point forward
# ==============================================================================

resource "helm_release" "argocd" {
  depends_on = [
    helm_release.longhorn,
  ]

  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "8.5.8"
  namespace        = "argocd"
  create_namespace = true
  timeout          = 1200

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
          type = "LoadBalancer"
          annotations = {
            "metallb.universe.tf/loadBalancerIPs" = "10.30.0.80"
          }
        }
        
        # Enable insecure mode for internal access behind Traefik
        extraArgs = ["--insecure"]
        
        config = {
          # Add SOPS/Vault integration if needed
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

# Configure ArgoCD repository credentials if GitHub token provided
resource "kubectl_manifest" "argocd_repo_secret" {
  count      = var.github_token != "" ? 1 : 0
  depends_on = [helm_release.argocd]

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = "private-repo"
      namespace = "argocd"
      labels    = { "argocd.argoproj.io/secret-type" = "repository" }
    }
    stringData = {
      type     = "git"
      url      = var.gitops_repo_url
      username = "git"
      password = var.github_token
    }
  })
}


# Create InfisicalSecret with ArgoCD label
resource "kubectl_manifest" "argocd_github_secret" {
  depends_on = [helm_release.argocd, helm_release.infisical]

  yaml_body = yamlencode({
    apiVersion = "secrets.infisical.com/v1alpha1"
    kind       = "InfisicalSecret"
    metadata = {
      name      = "argocd-repo-secret"
      namespace = "argocd"
      # Labels pass through to managed secret
      labels = {
        "argocd.argoproj.io/secret-type" = "repository"
      }
    }
    spec = {
      hostAPI = "https://app.infisical.com/api"
      authentication = {
        serviceToken = {
          secretsScope = {
            secretsPath = "/infrastructure"
            envSlug     = "prod"
          }
          serviceTokenSecretReference = {
            secretName      = "infisical-service-token"
            secretNamespace = "infisical-operator-system"
          }
        }
      }
      managedSecretReference = {
        secretName     = "private-repo"
        secretType     = "Opaque"
        creationPolicy = "Owner"
      }
    }
  })
}

# Wait for secret creation, then patch with ArgoCD fields
resource "time_sleep" "wait_for_argocd_secret" {
  depends_on      = [kubectl_manifest.argocd_github_secret]
  create_duration = "20s"
}

resource "null_resource" "patch_argocd_fields" {
  depends_on = [time_sleep.wait_for_argocd_secret]

  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG=${path.module}/generated/kubeconfig
      
      kubectl patch secret private-repo -n argocd --type merge -p '{
        "stringData": {
          "type": "git",
          "url": "${var.gitops_repo_url}",
          "username": "git"
        }
      }'
    EOT
  }

  triggers = {
    repo_url = var.gitops_repo_url
  }
}

# Deploy app-of-apps
resource "kubectl_manifest" "argocd_app_of_apps" {
  count      = var.gitops_repo_url != "" ? 1 : 0
  depends_on = [null_resource.patch_argocd_fields]

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

# ==============================================================================
# Output Files
# ==============================================================================

resource "local_file" "talosconfig" {
  content         = data.talos_client_configuration.this.talos_config
  filename        = "${path.module}/generated/talosconfig"
  file_permission = "0600"
}

resource "local_file" "kubeconfig" {
  content         = talos_cluster_kubeconfig.this.kubeconfig_raw
  filename        = "${path.module}/generated/kubeconfig"
  file_permission = "0600"
}