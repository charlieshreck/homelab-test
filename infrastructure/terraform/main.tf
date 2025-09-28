terraform {
  required_version = ">= 1.0"
  
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.6.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Proxmox Provider
provider "proxmox" {
  endpoint = "https://${var.proxmox_host}:8006/api2/json"
  username = "root@pam"
  password = var.proxmox_password
  insecure = true
  
  ssh {
    agent    = false
    username = "root"
    password = var.proxmox_password
  }
}

# Talos Provider
provider "talos" {}

# Generate machine secrets
resource "talos_machine_secrets" "this" {}

# Data source to generate dynamic VM IDs
locals {
  # Dynamic VM ID assignment starting from base ID
  vm_ids = {
    control_plane = var.vm_id_start
    workers = [for idx, _ in var.workers : var.vm_id_start + idx + 1]
    truenas = var.vm_id_start + length(var.workers) + 1
  }
}

# Control Plane VM Module
module "control_plane" {
  source = "./modules/talos-vm"
  
  vm_name        = var.control_plane.name
  vm_id          = local.vm_ids.control_plane
  target_node    = var.proxmox_node
  cores          = var.control_plane.cores
  memory         = var.control_plane.memory
  disk           = var.control_plane.disk
  ip_address     = var.control_plane.ip
  gateway        = var.network_gateway
  dns            = var.dns_servers
  network_bridge = var.network_bridge
  storage        = var.proxmox_vm_storage
  iso_storage    = var.proxmox_iso_storage
  talos_version  = var.talos_version
  gpu_passthrough = false
}

# Worker VMs Module
module "workers" {
  source = "./modules/talos-vm"
  count  = length(var.workers)
  
  vm_name        = var.workers[count.index].name
  vm_id          = local.vm_ids.workers[count.index]
  target_node    = var.proxmox_node
  cores          = var.workers[count.index].cores
  memory         = var.workers[count.index].memory
  disk           = var.workers[count.index].disk
  ip_address     = var.workers[count.index].ip
  gateway        = var.network_gateway
  dns            = var.dns_servers
  network_bridge = var.network_bridge
  storage        = var.proxmox_vm_storage
  iso_storage    = var.proxmox_iso_storage
  talos_version  = var.talos_version
  gpu_passthrough = var.workers[count.index].gpu
  
  # Additional disk for Longhorn storage
  additional_disks = [{
    size         = var.workers[count.index].longhorn_disk
    storage      = var.proxmox_longhorn_storage
    interface    = "scsi1"
  }]
}

# TrueNAS VM Module
module "truenas" {
  source = "./modules/truenas-vm"
  
  vm_name        = var.truenas_vm.name
  vm_id          = local.vm_ids.truenas
  target_node    = var.proxmox_node
  cores          = var.truenas_vm.cores
  memory         = var.truenas_vm.memory
  disk           = var.truenas_vm.disk
  ip_address     = var.truenas_vm.ip
  gateway        = var.network_gateway
  dns            = var.dns_servers
  network_bridge = var.network_bridge
  storage        = var.proxmox_truenas_storage
  iso_storage    = var.proxmox_iso_storage
  
  # Additional network for media serving
  media_network = {
    bridge = "vmbr2"
    ip     = var.truenas_vm.media_ip
    vlan   = 20
  }
}

# Generate Talos configuration
data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.cluster_name
  machine_type     = "controlplane"
  cluster_endpoint = var.cluster_endpoint
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  
  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/sda"
        }
        network = {
          hostname = var.control_plane.name
          interfaces = [
            {
              interface = "eth0"
              addresses = ["${var.control_plane.ip}/24"]
              routes = [
                {
                  network = "0.0.0.0/0"
                  gateway = var.network_gateway
                }
              ]
            }
          ]
          nameservers = var.dns_servers
        }
        kubelet = {
          extraArgs = {
            "rotate-certificates" = true
          }
        }
      }
      cluster = {
        network = {
          cni = {
            name = "none"  # We'll install Cilium
          }
        }
        proxy = {
          disabled = true  # Cilium will handle this
        }
      }
    })
  ]
}

data "talos_machine_configuration" "worker" {
  count = length(var.workers)
  
  cluster_name     = var.cluster_name
  machine_type     = "worker"
  cluster_endpoint = var.cluster_endpoint
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  
  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/sda"
        }
        network = {
          hostname = var.workers[count.index].name
          interfaces = [
            {
              interface = "eth0"
              addresses = ["${var.workers[count.index].ip}/24"]
              routes = [
                {
                  network = "0.0.0.0/0"
                  gateway = var.network_gateway
                }
              ]
            }
          ]
          nameservers = var.dns_servers
        }
        kubelet = {
          extraArgs = {
            "rotate-certificates" = true
          }
          extraMounts = var.workers[count.index].longhorn_disk > 0 ? [
            {
              destination = "/var/lib/longhorn"
              type        = "bind"
              source      = "/dev/sdb"
              options     = ["bind", "rshared", "rw"]
            }
          ] : []
        }
      }
    })
  ]
}

# Generate client configuration
data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = concat([var.control_plane.ip], [for w in var.workers : w.ip])
  endpoints            = [var.control_plane.ip]
}

# Apply machine configuration
resource "talos_machine_configuration_apply" "controlplane" {
  depends_on = [module.control_plane]
  
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = var.control_plane.ip
  
  lifecycle {
    ignore_changes = [machine_configuration_input]
  }
}

resource "talos_machine_configuration_apply" "worker" {
  depends_on = [module.workers]
  count      = length(var.workers)
  
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker[count.index].machine_configuration
  node                        = var.workers[count.index].ip
  
  lifecycle {
    ignore_changes = [machine_configuration_input]
  }
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

# Get kubeconfig
data "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_machine_bootstrap.this]
  
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.control_plane.ip
}

# Save configurations
resource "local_file" "talosconfig" {
  content  = data.talos_client_configuration.this.talos_config
  filename = "${path.module}/generated/talosconfig"
}

resource "local_file" "kubeconfig" {
  content  = data.talos_cluster_kubeconfig.this.kubeconfig_raw
  filename = "${path.module}/generated/kubeconfig"
}

# Outputs
output "talos_config" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}

output "kubeconfig" {
  value     = data.talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive = true
}

output "cluster_info" {
  value = {
    control_plane_ip = var.control_plane.ip
    worker_ips      = [for w in var.workers : w.ip]
    truenas_ip      = var.truenas_vm.ip
    vm_ids = {
      control_plane = local.vm_ids.control_plane
      workers       = local.vm_ids.workers
      truenas       = local.vm_ids.truenas
    }
  }
}
