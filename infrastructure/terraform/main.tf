terraform {
  required_version = ">= 1.0"
  
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.84.0"
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

# Proxmox Provider - Using password authentication
provider "proxmox" {
  endpoint = "https://${var.proxmox_host}:8006"
  username = var.proxmox_user
  password = var.proxmox_password
  insecure = true
}

# Talos Provider
provider "talos" {}

# Generate machine secrets
resource "talos_machine_secrets" "this" {}

# Data source to generate dynamic VM IDs
locals {
  vm_ids = {
    control_plane = var.vm_id_start
    workers = [for idx, _ in var.workers : var.vm_id_start + idx + 1]
    truenas = var.vm_id_start + length(var.workers) + 1
  }
  
  # Fixed MAC addresses for consistent DHCP reservations
  mac_addresses = {
    control_plane = "52:54:00:10:30:50"
    workers = [
      "52:54:00:10:30:51",
      "52:54:00:10:30:52"
    ]
    truenas = "52:54:00:10:30:53"
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
  gateway        = var.prod_gateway
  dns            = var.dns_servers
  network_bridge = var.network_bridge
  storage        = var.proxmox_storage
  iso_storage    = var.proxmox_iso_storage
  talos_version  = var.talos_version
  gpu_passthrough = false
  mac_address    = local.mac_addresses.control_plane
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
  gateway        = var.prod_gateway
  dns            = var.dns_servers
  network_bridge = var.network_bridge
  storage        = var.proxmox_storage
  iso_storage    = var.proxmox_iso_storage
  talos_version  = var.talos_version
  gpu_passthrough = var.workers[count.index].gpu
  mac_address    = local.mac_addresses.workers[count.index]
  
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
  gateway        = var.prod_gateway
  dns            = var.dns_servers
  network_bridge = var.network_bridge
  storage        = var.proxmox_truenas_storage
  iso_storage    = var.proxmox_iso_storage
  mac_address    = local.mac_addresses.truenas
}

# Generate Talos configuration
data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.cluster_name
  machine_type     = "controlplane"
  cluster_endpoint = "https://172.10.0.11:6443"
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
                  gateway = var.prod_gateway
                }
              ]
            },
            {
              interface = "eth1"
              addresses = ["172.10.0.11/24"]
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
  cluster_endpoint = "https://172.10.0.11:6443"
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
                  gateway = var.prod_gateway
                }
              ]
            },
            {
              interface = "eth1"
              addresses = ["172.10.0.${12 + count.index}/24"]
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
    ignore_changes = [machine_configuration_input, node, endpoint]
  }
}

resource "talos_machine_configuration_apply" "worker" {
  depends_on = [module.workers]
  count      = length(var.workers)
  
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker[count.index].machine_configuration
  node                        = var.workers[count.index].ip
  
  lifecycle {
    ignore_changes = [machine_configuration_input, node, endpoint]
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
resource "talos_cluster_kubeconfig" "this" {
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
  content  = talos_cluster_kubeconfig.this.kubeconfig_raw
  filename = "${path.module}/generated/kubeconfig"
}
