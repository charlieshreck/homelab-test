# ==============================================================================
# data.tf - Defines the Talos machine configurations
#
# FIXES APPLIED:
# 1. Removed VIP configuration that was causing extra IP assignment
# 2. Changed cluster endpoint to use control plane IP directly instead of SRV record
# 3. Simplified network configuration for reliability
# ==============================================================================

# ==============================================================================
# Talos Version Discovery
# ==============================================================================

data "external" "talos_config" {
  program = ["bash", "${path.module}/../scripts/get-talos-version.sh"]
}

# ==============================================================================
# Talos Client Configuration
# ==============================================================================

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = [var.control_plane.ip]
  endpoints            = [var.control_plane.ip]
}

# ==============================================================================
# Talos Machine Configuration - Control Plane
# ==============================================================================

data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.cluster_name
  # FIX: Use direct IP instead of SRV record for more reliable initial bootstrap
  cluster_endpoint = "https://${var.control_plane.ip}:6443"
  machine_type     = "controlplane"
  talos_version    = local.talos_version
  machine_secrets  = talos_machine_secrets.this.machine_secrets

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk  = "/dev/sda"
          image = "factory.talos.dev/installer/${local.schematic_id}:${local.talos_version}"
        }
        network = {
          hostname = var.control_plane.name
          interfaces = [
            # Primary Interface (10.30.x.x network)
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
              # FIX: Removed VIP configuration - this was causing the extra /32 IP
            },
            # Secondary/Internal Interface (172.x.x.x network)
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

# ==============================================================================
# Talos Machine Configuration - Workers
# ==============================================================================

data "talos_machine_configuration" "worker" {
  for_each = var.workers

  cluster_name     = var.cluster_name
  # FIX: Use direct IP instead of SRV record
  cluster_endpoint = "https://${var.control_plane.ip}:6443"
  machine_type     = "worker"
  talos_version    = local.talos_version
  machine_secrets  = talos_machine_secrets.this.machine_secrets

  config_patches = [
    yamlencode(merge(
      {
        machine = {
          install = {
            disk  = "/dev/sda"
            image = "factory.talos.dev/installer/${local.schematic_id}:${local.talos_version}"
          }
          # Longhorn disk configuration
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
            hostname = each.value.name
            interfaces = [
              # Primary Interface (10.30.x.x network)
              {
                deviceSelector = {
                  hardwareAddr = local.mac_addresses.workers[each.key]
                }
                dhcp      = false
                addresses = ["${each.value.ip}/24"]
                routes = [
                  {
                    network = "0.0.0.0/0"
                    gateway = var.prod_gateway
                  }
                ]
              },
              # Secondary/Internal Interface (172.x.x.x network)
              {
                deviceSelector = {
                  hardwareAddr = local.internal_mac_addresses.workers[each.key]
                }
                dhcp      = false
                addresses = ["172.10.0.${51 + index(local.worker_keys, each.key)}/24"]
              }
            ]
            nameservers = var.dns_servers
          }
        }
      },
      # GPU configuration if enabled
      each.value.gpu ? {
        machine = {
          sysctls = {
            "net.core.bpf_jit_harden" = "0"
          }
        }
      } : {}
    ))
  ]
}