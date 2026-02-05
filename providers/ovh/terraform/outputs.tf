output "master_public_ips" {
  description = "Public IPs of master nodes"
  value       = ovh_cloud_project_instance.k3s_master[*].ip_address
}

output "worker_public_ips" {
  description = "Public IPs of worker nodes"
  value       = ovh_cloud_project_instance.k3s_worker[*].ip_address
}

output "k3s_api_endpoint" {
  description = "K3s API endpoint"
  value       = length(ovh_cloud_project_instance.k3s_master) > 0 ? "https://${ovh_cloud_project_instance.k3s_master[0].ip_address}:6443" : ""
}

# Generar inventory de Ansible
output "ansible_inventory" {
  description = "Ansible inventory in YAML format"
  value = templatefile("${path.module}/templates/inventory.tpl", {
    master_ips  = zipmap(
      ovh_cloud_project_instance.k3s_master[*].name,
      ovh_cloud_project_instance.k3s_master[*].ip_address
    )
    worker_ips = zipmap(
      ovh_cloud_project_instance.k3s_worker[*].name,
      ovh_cloud_project_instance.k3s_worker[*].ip_address
    )
  })
}
