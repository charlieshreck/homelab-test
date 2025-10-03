terraform {
  required_version = ">= 1.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.84.1"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.9.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5.3"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.4"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0.2"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.19"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
  }
}

provider "proxmox" {
  endpoint = "https://${var.proxmox_host}:8006"
  username = var.proxmox_user
  password = var.proxmox_password
  insecure = true
}

provider "talos" {}

provider "helm" {
  kubernetes = {
    host                   = try(talos_cluster_kubeconfig.this.kubernetes_client_configuration.host, "")
    client_certificate     = try(base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate), "")
    client_key             = try(base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key), "")
    cluster_ca_certificate = try(base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate), "")
  }
}

provider "kubectl" {
  host                   = try(talos_cluster_kubeconfig.this.kubernetes_client_configuration.host, "")
  client_certificate     = try(base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate), "")
  client_key             = try(base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key), "")
  cluster_ca_certificate = try(base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate), "")
  load_config_file       = false
}

provider "kubernetes" {
  host                   = try(talos_cluster_kubeconfig.this.kubernetes_client_configuration.host, "")
  client_certificate     = try(base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate), "")
  client_key             = try(base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key), "")
  cluster_ca_certificate = try(base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate), "")
}

resource "talos_machine_secrets" "this" {}

locals {
  vm_ids = {
    control_plane = var.vm_id_start
    workers       = [for idx, _ in var.workers : var.vm_id_start + idx + 1]
    truenas       = var.vm_id_start + length(var.workers) + 1
  }

  mac_addresses = {
    control_plane = "52:54:00:10:30:50"
    workers = [
      "52:54:00:10:30:51",
      "52:54:00:10:30:52"
    ]
    truenas = "52:54:00:10:30:53"
  }

  internal_mac_addresses = {
    control_plane = "52:54:00:17:21:50"
    workers = [
      "52:54:00:17:21:51",
      "52:54:00:17:21:52"
    ]
  }
}

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
  talos_version        = var.talos_version
  gpu_passthrough      = false
  gpu_pci_id           = null
  mac_address          = local.mac_addresses.control_plane
  internal_mac_address = local.internal_mac_addresses.control_plane
  additional_disks     = []
}

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
  talos_version        = var.talos_version
  gpu_passthrough      = var.workers[count.index].gpu
  gpu_pci_id           = var.workers[count.index].gpu ? var.workers[count.index].gpu_pci_id : null
  mac_address          = local.mac_addresses.workers[count.index]
  internal_mac_address = local.internal_mac_addresses.workers[count.index]

  # Longhorn storage disk
  additional_disks = [{
    size      = var.workers[count.index].longhorn_disk
    storage   = var.proxmox_longhorn_storage
    interface = "scsi1"
  }]
}

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

data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.cluster_name
  machine_type     = "controlplane"
  cluster_endpoint = "https://${var.control_plane.ip}:6443"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = var.talos_version

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/sda"
          image = "factory.talos.dev/installer/0751f1135eff2bc906854a62cc450c94f3dc65428d42110fc7998db8959dd5e5:v1.11.2"

        }
        network = {
          hostname = var.control_plane.name
          interfaces = [
            {
              deviceSelector = {
                hardwareAddr = local.mac_addresses.control_plane
              }
              dhcp      = false
              addresses = ["${var.control_plane.ip}/24"]
              routes = [
                {
                  network = "0.0.0.0/0"
                  gateway = var.prod_gateway
                }
              ]
            },
            {
              deviceSelector = {
                hardwareAddr = local.internal_mac_addresses.control_plane
              }
              dhcp      = false
              addresses = ["172.10.0.50/24"]
            }
          ]
          nameservers = var.dns_servers
        }
        kubelet = {
          extraArgs = {
            "rotate-certificates" = "true"
          }
        }
      }
      cluster = {
        network = {
          cni = {
            name = "none"
          }
        }
        proxy = {
          disabled = true
        }
      }
    })
  ]
}

data "talos_machine_configuration" "worker" {
  count = length(var.workers)

  cluster_name     = var.cluster_name
  machine_type     = "worker"
  cluster_endpoint = "https://${var.control_plane.ip}:6443"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = var.talos_version

  config_patches = [
    yamlencode(merge(
      {
        machine = {
          install = {
            disk = "/dev/sda"
          image = "factory.talos.dev/installer/0751f1135eff2bc906854a62cc450c94f3dc65428d42110fc7998db8959dd5e5:v1.11.2"
          }
        disks = [
          {
            device = "/dev/sdb"
            partitions = [
               {
                 mountpoint = "/var/lib/longhorn"
               }
              ]
            }
          ]
          kubelet = {
            extraMounts = [
              {
                destination = "/var/lib/longhorn"
                type        = "bind"
                source      = "/var/lib/longhorn"
                options     = ["bind", "rshared", "rw"]
              }
            ]
            extraArgs = {
              "rotate-certificates" = "true"
            }
          }
          network = {
            hostname = var.workers[count.index].name
            interfaces = [
              {
                deviceSelector = {
                  hardwareAddr = local.mac_addresses.workers[count.index]
                }
                dhcp      = false
                addresses = ["${var.workers[count.index].ip}/24"]
                routes = [
                  {
                    network = "0.0.0.0/0"
                    gateway = var.prod_gateway
                  }
                ]
              },
              {
                deviceSelector = {
                  hardwareAddr = local.internal_mac_addresses.workers[count.index]
                }
                dhcp      = false
                addresses = ["172.10.0.${51 + count.index}/24"]
              }
            ]
            nameservers = var.dns_servers
          }
        }
      },
      var.workers[count.index].gpu ? {
        machine = {
          sysctls = {
            "net.core.bpf_jit_harden" = "0"
          }
        }
      } : {}
    ))
  ]
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = concat([var.control_plane.ip], [for w in var.workers : w.ip])
  endpoints            = [var.control_plane.ip]
}

resource "talos_machine_configuration_apply" "controlplane" {
  depends_on = [module.control_plane]

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = var.control_plane.ip
}

resource "talos_machine_configuration_apply" "worker" {
  depends_on = [module.workers]
  count      = length(var.workers)

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker[count.index].machine_configuration
  node                        = var.workers[count.index].ip
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [
    talos_machine_configuration_apply.controlplane,
    talos_machine_configuration_apply.worker
  ]

  node                 = var.control_plane.ip
  client_configuration = talos_machine_secrets.this.client_configuration
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_machine_bootstrap.this]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.control_plane.ip
}

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

# Wait for MetalLB to be ready
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

# MetalLB IP Address Pool
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

# MetalLB L2 Advertisement
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

# Install Longhorn with Talos-specific configuration
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

      defaultSettings = {
        defaultDataPath = "/var/lib/longhorn"
      }
      
      csi = {
        kubeletRootDir = "/var/lib/kubelet"
        attacherReplicaCount = 3
        provisionerReplicaCount = 3
        resizerReplicaCount = 3
        snapshotterReplicaCount = 3
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

# Install Cert Manager
resource "helm_release" "cert_manager" {
  depends_on = [null_resource.wait_for_cilium]

  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.18.2"
  namespace        = "cert-manager"
  create_namespace = true

  set = [
    {
      name  = "crds.enabled"
      value = "true"
    }
  ]
}

# Install ArgoCD
resource "helm_release" "argocd" {
  depends_on = [helm_release.longhorn]

  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "8.5.8"
  namespace        = "argocd"
  create_namespace = true

  set = [
    {
      name  = "server.service.type"
      value = "LoadBalancer"
    }
  ]
}

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

resource "kubectl_manifest" "argocd_app_of_apps" {
  count      = var.gitops_repo_url != "" ? 1 : 0
  depends_on = [helm_release.argocd]

  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "app-of-apps"
      namespace = "argocd"
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.gitops_repo_url
        targetRevision = var.gitops_repo_branch
        path           = "applications"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "argocd"
      }
      syncPolicy = {
        automated   = { prune = true, selfHeal = true }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  })
}

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