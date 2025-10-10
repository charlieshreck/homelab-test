# ==============================================================================
# main.tf - V3 with Multus CNI and Longhorn via argocd
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
  longhorn_mac_address = local.longhorn_mac_addresses.control_plane
  media_mac_address    = local.media_mac_addresses.control_plane
  additional_disks     = []
}

# Deploy worker VMs
module "workers" {
  source   = "./modules/talos-vm"
  for_each = var.workers

  vm_name              = each.value.name
  vm_id                = local.vm_ids.workers[each.key]
  target_node          = var.proxmox_node
  cores                = each.value.cores
  memory               = each.value.memory
  disk                 = each.value.disk
  ip_address           = each.value.ip
  gateway              = var.prod_gateway
  dns                  = var.dns_servers
  network_bridge       = var.network_bridge
  storage              = var.proxmox_storage
  iso_storage          = var.proxmox_iso_storage
  talos_version        = local.talos_version
  iso_file             = proxmox_virtual_environment_download_file.talos_iso.id
  gpu_passthrough      = each.value.gpu
  gpu_pci_id           = each.value.gpu ? each.value.gpu_pci_id : null
  mac_address          = local.mac_addresses.workers[each.key]
  internal_mac_address = local.internal_mac_addresses.workers[each.key]
  longhorn_mac_address = local.longhorn_mac_addresses.workers[each.key]
  media_mac_address    = local.media_mac_addresses.workers[each.key]

  additional_disks = [{
    size      = each.value.longhorn_disk
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
  cluster_mac_address  = local.internal_mac_addresses.truenas
  longhorn_mac_address = local.longhorn_mac_addresses.truenas
  media_mac_address    = local.media_mac_addresses.truenas
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
# Platform Layer: CNI, Load Balancer, Storage
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

# Install MetalLB
resource "helm_release" "metallb" {
  depends_on = [null_resource.wait_for_cilium]

  name             = "metallb"
  repository       = "https://metallb.github.io/metallb"
  chart            = "metallb"
  version          = "0.15.2"
  namespace        = "metallb-system"
  create_namespace = true
  timeout          = 600
  wait             = false
}

resource "kubernetes_labels" "metallb_namespace_security" {
  depends_on = [helm_release.metallb]
  
  api_version = "v1"
  kind        = "Namespace"
  metadata {
    name = "metallb-system"
  }
  labels = {
    "pod-security.kubernetes.io/enforce" = "privileged"
    "pod-security.kubernetes.io/audit"   = "privileged"
    "pod-security.kubernetes.io/warn"    = "privileged"
  }
}

# Wait for MetalLB controller
resource "null_resource" "wait_for_metallb" {
  depends_on = [helm_release.metallb]

  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG=${path.module}/generated/kubeconfig
      
      echo "Waiting for MetalLB controller to be ready..."
      kubectl wait --for=condition=ready pod \
        -l app.kubernetes.io/name=metallb,app.kubernetes.io/component=controller \
        -n metallb-system \
        --timeout=600s
      echo "✅ MetalLB controller is ready."
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
# ==============================================================================
# GitOps Controller: ArgoCD
# ==============================================================================

resource "helm_release" "argocd" {
  depends_on = [null_resource.wait_for_metallb]

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
          type = "LoadBalancer"
          annotations = {
            "metallb.universe.tf/loadBalancerIPs" = "10.30.0.80"
          }
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
  depends_on = [null_resource.wait_and_patch_secret]

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