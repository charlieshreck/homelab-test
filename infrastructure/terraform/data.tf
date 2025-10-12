# ==============================================================================
# data.tf - Talos machine configurations (Single NIC)
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
            # Primary Interface (10.30.x.x network) - SINGLE NIC
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
              # Primary Interface (10.30.x.x network) - SINGLE NIC
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
