# Centralized locals for computed values and constants

locals {
  # Talos configuration
  talos_version       = data.external.talos_config.result.version
  schematic_id        = data.external.talos_config.result.schematic_id
  talos_factory_image = "factory.talos.dev/installer/${local.schematic_id}:${local.talos_version}"
  talos_iso_name      = "metal-${local.talos_version}-${substr(local.schematic_id, 0, 8)}.iso"

  # VM ID allocation
  vm_ids = {
    control_plane = var.vm_id_start
    workers       = [for idx, _ in var.workers : var.vm_id_start + idx + 1]
    truenas       = var.vm_id_start + length(var.workers) + 1
  }

  # MAC address allocation for DHCP reservations
  # Format: 52:54:00:XX:YY:ZZ where XX:YY:ZZ matches last 3 octets of IP
  mac_addresses = {
    control_plane = "52:54:00:10:30:50"  # 10.30.0.50
    workers = [
      "52:54:00:10:30:51",  # 10.30.0.51
      "52:54:00:10:30:52",  # 10.30.0.52
    ]
    truenas = "52:54:00:10:30:53"
  }

  # Internal network MAC addresses
  internal_mac_addresses = {
    control_plane = "52:54:00:17:21:50"  # 172.10.0.50
    workers = [
      "52:54:00:17:21:51",  # 172.10.0.51
      "52:54:00:17:21:52",  # 172.10.0.52
    ]
  }

  # Common tags/labels
  common_labels = {
    "managed-by" = "terraform"
    "cluster"    = var.cluster_name
  }
}
