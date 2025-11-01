# ==============================================================================
# data.tf - Talos machine configurations (Dual NIC for workers) - Mayastor
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

data "talos_machine_configuration" "storage_node" {
  for_each = var.storage_nodes

  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.control_plane.ip}:6443"
  machine_type     = "worker"
  talos_version    = local.talos_version
  machine_secrets  = talos_machine_secrets.this.machine_secrets

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk  = "/dev/sda"
          image = "factory.talos.dev/installer/${local.schematic_id}:${local.talos_version}"
        }
        # Mayastor disk configuration (helford storage - 1TB)
        disks = [{
          device = "/dev/sdb"
          # Mayastor uses raw block devices - no partitions
        }]
        kernel = {
          modules = [{ name = "nvme-tcp" }]
        }
        kubelet = {
          extraArgs = {
            "rotate-certificates" = "true"
          }
        }
        sysctls = {
          "vm.nr_hugepages"      = "1024"
          "vm.overcommit_memory" = "1"
          "vm.panic_on_oom"      = "0"
        }
        network = {
          hostname = each.value.name
          interfaces = [
            {
              deviceSelector = {
                hardwareAddr = local.mac_addresses.storage[each.key]
              }
              dhcp      = true  # Use DHCP with reservation in OPNsense
              routes = [{
                network = "0.0.0.0/0"
                gateway = var.prod_gateway
              }]
            },
            {
              deviceSelector = {
                hardwareAddr = local.storage_mac_addresses.storage[each.key]
              }
              dhcp      = true  # Use DHCP with reservation in OPNsense
            }
          ]
          nameservers = var.dns_servers
        }
      }
      cluster = {
        network = { cni = { name = "none" } }
        proxy = { disabled = true }
      }
    })
  ]
}

# ==============================================================================
# Talos Machine Configuration - Storage Nodes
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
            # Primary Interface (10.10.0.0/24 network) - Management
            {
              deviceSelector = {
                hardwareAddr = local.mac_addresses.control_plane
              }
              dhcp      = true  # Use DHCP with reservation in OPNsense
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
# Talos Machine Configuration - Workers (Dual NIC with Mayastor)
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
          # Mayastor disk configuration (helford storage - 1TB)
          # Mayastor uses /dev/sdb as a raw block device (no filesystem)
          disks = [
            {
              device = "/dev/sdb"
              # Mayastor uses raw block devices - no partitions
            }
          ]

          # Kernel modules for Mayastor (requires nvme-tcp and hugepages)
          kernel = {
            modules = [
              {
                name = "nvme-tcp"
              }
            ]
          }

          kubelet = {
            extraArgs = {
              "rotate-certificates" = "true"
            }
          }

          # Sysctls for Mayastor (requires huge pages)
          sysctls = {
            "vm.nr_hugepages"      = "1024"
            "vm.overcommit_memory" = "1"
            "vm.panic_on_oom"      = "0"
          }


          network = {
            hostname = each.value.name
            interfaces = [
              # Primary Interface (10.10.0.0/24 network) - Management
              {
                deviceSelector = {
                  hardwareAddr = local.mac_addresses.workers[each.key]
                }
                dhcp      = true  # Use DHCP with reservation in OPNsense
                routes = [
                  {
                    network = "0.0.0.0/0"
                    gateway = var.prod_gateway
                  }
                ]
              },
              # Storage Interface (10.11.0.0/24 network) - Mayastor/TrueNAS
              {
                deviceSelector = {
                  hardwareAddr = local.storage_mac_addresses.workers[each.key]
                }
                dhcp      = true  # Use DHCP with reservation in OPNsense
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