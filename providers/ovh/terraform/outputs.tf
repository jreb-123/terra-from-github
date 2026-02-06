output "master_public_ips" {
  description = "Public IPs of master nodes"
  value       = openstack_networking_floatingip_v2.k3s_master_fip[*].address
}

output "master_private_ips" {
  description = "Private IPs of master nodes"
  value       = openstack_compute_instance_v2.k3s_master[*].access_ip_v4
}

output "worker_public_ips" {
  description = "Public IPs of worker nodes"
  value       = openstack_networking_floatingip_v2.k3s_worker_fip[*].address
}

output "worker_private_ips" {
  description = "Private IPs of worker nodes"
  value       = openstack_compute_instance_v2.k3s_worker[*].access_ip_v4
}

output "k3s_api_endpoint" {
  description = "K3s API endpoint"
  value       = "https://${openstack_networking_floatingip_v2.k3s_master_fip[0].address}:6443"
}

# Generar inventory de Ansible
output "ansible_inventory" {
  description = "Ansible inventory in YAML format"
  value = templatefile("${path.module}/templates/inventory.tpl", {
    master_ips  = zipmap(
      openstack_compute_instance_v2.k3s_master[*].name,
      openstack_networking_floatingip_v2.k3s_master_fip[*].address
    )
    worker_ips = zipmap(
      openstack_compute_instance_v2.k3s_worker[*].name,
      openstack_networking_floatingip_v2.k3s_worker_fip[*].address
    )
  })
}
