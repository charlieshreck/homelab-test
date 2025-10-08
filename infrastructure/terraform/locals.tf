# ==============================================================================
# locals.tf - Centralized locals for computed values and constants
#
# FIXES APPLIED:
# 1. Fixed MAC address format to use decimal instead of hex for last octet
# 2. Ensured worker_keys are sorted for consistent ordering
# ==============================================================================

locals {
  # Talos configuration
  talos_version       = data.external.talos_config.result.version
  schematic_id        = data.external.talos_config.result.schematic_id
  talos_factory_image = "factory.talos.dev/installer/${local.schematic_id}:${local.talos_version}"
  talos_iso_name      = "metal-${local.talos_version}-${substr(local.schematic_id, 0, 8)}.iso"

  # Worker keys for ordered iteration (ensures consistent ordering)
  worker_keys = sort(keys(var.workers))

  # VM ID allocation
  vm_ids = {
    control_plane = var.vm_id_start
    workers       = { for idx, key in local.worker_keys : key => var.vm_id_start + idx + 1 }
    truenas       = var.vm_id_start + length(var.workers) + 1
  }

 # Primary network MAC addresses (eth0 - 10.30.0.x)
  mac_addresses = {
    control_plane = "52:54:00:10:30:50"
    workers = { 
      for idx, key in local.worker_keys : key => 
      format("52:54:00:10:30:%02d", 51 + idx)
    }
    truenas = "52:54:00:10:30:14"
  }

  # Internal network MAC addresses (eth1 - 172.10.0.x)
  internal_mac_addresses = {
    control_plane = "52:54:00:ac:0a:32"
    workers = { 
      for idx, key in local.worker_keys : key => 
      format("52:54:00:ac:0a:%02x", 51 + idx)
    }
    truenas = "52:54:00:ac:0a:14"
  }

  # Longhorn storage network MAC addresses (eth2 - 172.20.0.x)
  longhorn_mac_addresses = {
    control_plane = "52:54:00:ac:0b:32"
    workers = { 
      for idx, key in local.worker_keys : key => 
      format("52:54:00:ac:0b:%02x", 51 + idx)
    }
    truenas = "52:54:00:ac:0b:14"
  }

  # Media network MAC addresses (eth3 - 172.30.0.x)
  media_mac_addresses = {
    control_plane = "52:54:00:ac:0c:32"
    workers = { 
      for idx, key in local.worker_keys : key => 
      format("52:54:00:ac:0c:%02x", 51 + idx)
    }
    truenas = "52:54:00:ac:0c:14"
  }

  # Common tags/labels
  common_labels = {
    "managed-by" = "terraform"
    "cluster"    = var.cluster_name
  }
}