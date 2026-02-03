# terraform/outputs.tf
output "vm_external_ip" {
  description = "IP externa de la VM"
  value       = google_compute_instance.vm_instance.network_interface[0].access_config[0].nat_ip
}

output "vm_name" {
  description = "Nombre de la VM"
  value       = google_compute_instance.vm_instance.name
}
