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

  # FIX: MAC address allocation - corrected to use decimal format
  # Format: 52:54:00:XX:YY:ZZ where the last octet matches the IP's last octet
  mac_addresses = {
    control_plane = "52:54:00:10:30:50" # 10.30.0.50
    workers = { 
      for idx, key in local.worker_keys : key => 
      format("52:54:00:10:30:%02d", 51 + idx) # %02d for decimal, not %02x for hex
    }
    truenas = "52:54:00:10:30:14" # 10.30.0.20 = 0x14 in hex, but we use decimal for consistency
  }

  # Internal network MAC addresses
  internal_mac_addresses = {
    control_plane = "52:54:00:ac:0a:32" # ac:0a:32 = 172.10.50 in hex
    workers = { 
      for idx, key in local.worker_keys : key => 
      format("52:54:00:ac:0a:%02x", 51 + idx) # Convert to hex for 172.10.0.51+
    }
  }

  # Common tags/labels
  common_labels = {
    "managed-by" = "terraform"
    "cluster"    = var.cluster_name
  }
}