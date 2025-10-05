# Data sources for external information and Talos configuration

# Automatic Talos version and schematic generation
data "external" "talos_config" {
  program = ["${path.module}/../scripts/get-latest-talos.sh"]
}

# Generate Talos machine configuration for control plane
data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.cluster_name
  machine_type     = "controlplane"
  cluster_endpoint = "https://${var.control_plane.ip}:6443"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = local.talos_version

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk  = "/dev/sda"
          image = local.talos_factory_image
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

# Generate Talos machine configuration for workers
data "talos_machine_configuration" "worker" {
  count = length(var.workers)

  cluster_name     = var.cluster_name
  machine_type     = "worker"
  cluster_endpoint = "https://${var.control_plane.ip}:6443"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = local.talos_version

  config_patches = [
    yamlencode(merge(
      {
        machine = {
          install = {
            disk  = "/dev/sda"
            image = local.talos_factory_image
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

# Generate Talos client configuration
data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = concat([var.control_plane.ip], [for w in var.workers : w.ip])
  endpoints            = [var.control_plane.ip]
}
