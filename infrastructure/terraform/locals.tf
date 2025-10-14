# ==============================================================================
# locals.tf - Single NIC Architecture
# ==============================================================================

locals {
  # Talos configuration
  talos_version       = data.external.talos_config.result.version
  schematic_id        = data.external.talos_config.result.schematic_id
  talos_factory_image = "factory.talos.dev/installer/${local.schematic_id}:${local.talos_version}"
  talos_iso_name      = "metal-${local.talos_version}-${substr(local.schematic_id, 0, 8)}.iso"

  # Worker keys for ordered iteration
  worker_keys = sort(keys(var.workers))

  # VM ID allocation
  vm_ids = {
    control_plane = var.vm_id_start
    workers       = { for idx, key in local.worker_keys : key => var.vm_id_start + idx + 1 }
#    truenas       = var.vm_id_start + length(var.workers) + 1
  }

  # Primary network MAC addresses only (eth0 - 10.30.0.x)
  mac_addresses = {
    control_plane = "52:54:00:10:30:50"
    workers = { 
      for idx, key in local.worker_keys : key => 
      format("52:54:00:10:30:%02d", 51 + idx)
    }
#    truenas = "52:54:00:10:30:14"
  }

  # Common tags/labels
  common_labels = {
    "managed-by" = "terraform"
    "cluster"    = var.cluster_name
  }
}
