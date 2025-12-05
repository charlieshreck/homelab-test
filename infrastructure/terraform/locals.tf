# ==============================================================================
# locals.tf - Dual NIC Architecture for Mayastor Storage
# ==============================================================================

locals {
  # Talos configuration
  talos_version       = data.external.talos_config.result.version
  schematic_id        = data.external.talos_config.result.schematic_id
  talos_factory_image = "factory.talos.dev/installer/${local.schematic_id}:${local.talos_version}"
  talos_iso_name      = "metal-${local.talos_version}-${substr(local.schematic_id, 0, 8)}.iso"

  # Node keys
  worker_keys  = sort(keys(var.workers))
  storage_keys = sort(keys(var.storage_nodes))

  # VM ID allocation
  vm_ids = {
    control_plane = var.vm_id_start
    workers       = { for idx, key in local.worker_keys : key => var.vm_id_start + idx + 1 }
    storage       = { for idx, key in local.storage_keys : key => var.vm_id_start + length(var.workers) + idx + 1 }
  }

  # MAC addresses for management network (10.10.0.0/24 on vmbr0)
  mac_addresses = {
    control_plane = "52:54:00:10:10:10"
    workers = {
      for idx, key in local.worker_keys : key =>
      format("52:54:00:10:10:%02d", 11 + idx)
    }
    storage = {
      for idx, key in local.storage_keys : key =>
      format("52:54:00:10:10:%02d", 21 + idx)
    }
  }

  # MAC addresses for storage network (10.11.0.0/24 on vmbr1)
  # Used for Mayastor traffic
  storage_mac_addresses = {
    workers = {
      for idx, key in local.worker_keys : key =>
      format("52:54:00:10:11:%02d", 11 + idx)
    }
    storage = {
      for idx, key in local.storage_keys : key =>
      format("52:54:00:10:11:%02d", 21 + idx)
    }
  }

  # Common labels
  common_labels = {
    "managed-by" = "terraform"
    "cluster"    = var.cluster_name
  }
}