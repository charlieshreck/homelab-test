output "control_plane_ip" {
  description = "Control plane node IP"
  value       = var.control_plane.ip
}

output "worker_ips" {
  description = "Worker node IPs"
  value       = [for w in var.workers : w.ip]
}

output "truenas_ip" {
  description = "TrueNAS IP"
  value       = var.truenas.ip
}

output "cluster_name" {
  description = "Kubernetes cluster name"
  value       = var.cluster_name
}

output "talos_version" {
  description = "Talos version"
  value       = var.talos_version
}

output "kubernetes_version" {
  description = "Kubernetes version"
  value       = var.kubernetes_version
}
