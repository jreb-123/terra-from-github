# Crear instancias master
resource "ovh_cloud_project_instance" "k3s_master" {
  count        = var.master_count
  service_name = var.service_name
  name         = "${var.cluster_name}-master-${count.index + 1}"
  region       = var.region
  flavor_name  = var.flavor_master
  image_name   = var.image_name

  # Inyectar clave SSH en la instancia
  user_data = base64encode(templatefile("${path.module}/templates/cloud-init-master.tpl", {
    ssh_public_key = var.ssh_public_key
    node_index     = count.index + 1
  }))
}

# Crear instancias worker
resource "ovh_cloud_project_instance" "k3s_worker" {
  count        = var.worker_count
  service_name = var.service_name
  name         = "${var.cluster_name}-worker-${count.index + 1}"
  region       = var.region
  flavor_name  = var.flavor_worker
  image_name   = var.image_name

  user_data = base64encode(templatefile("${path.module}/templates/cloud-init-worker.tpl", {
    ssh_public_key = var.ssh_public_key
    node_index     = count.index + 1
  }))
}
