# Obtener la imagen de Ubuntu
data "openstack_images_image_v2" "ubuntu" {
  name        = var.image_name
  most_recent = true
}

# SSH Key pair
resource "openstack_compute_keypair_v2" "k3s_keypair" {
  name       = "${var.cluster_name}-keypair"
  public_key = var.ssh_public_key
}

# Master nodes
resource "openstack_compute_instance_v2" "k3s_master" {
  count           = var.master_count
  name            = "${var.cluster_name}-master-${count.index + 1}"
  flavor_name     = var.flavor_master
  image_id        = data.openstack_images_image_v2.ubuntu.id
  key_pair        = openstack_compute_keypair_v2.k3s_keypair.name
  security_groups = [openstack_networking_secgroup_v2.k3s_secgroup.name]

  network {
    uuid = openstack_networking_network_v2.k3s_network.id
  }

  user_data = <<-EOF
    #cloud-config
    package_update: true
    package_upgrade: true
    packages:
      - curl
      - wget
      - git
    runcmd:
      - echo "Master node ${count.index + 1} initialized" > /var/log/cloud-init-done.log
  EOF

  metadata = {
    role         = "master"
    cluster_name = var.cluster_name
  }
}

# Floating IPs para masters
resource "openstack_networking_floatingip_v2" "k3s_master_fip" {
  count = var.master_count
  pool  = "Ext-Net"
}

resource "openstack_compute_floatingip_associate_v2" "k3s_master_fip_assoc" {
  count       = var.master_count
  floating_ip = openstack_networking_floatingip_v2.k3s_master_fip[count.index].address
  instance_id = openstack_compute_instance_v2.k3s_master[count.index].id
}

# Worker nodes
resource "openstack_compute_instance_v2" "k3s_worker" {
  count           = var.worker_count
  name            = "${var.cluster_name}-worker-${count.index + 1}"
  flavor_name     = var.flavor_worker
  image_id        = data.openstack_images_image_v2.ubuntu.id
  key_pair        = openstack_compute_keypair_v2.k3s_keypair.name
  security_groups = [openstack_networking_secgroup_v2.k3s_secgroup.name]

  network {
    uuid = openstack_networking_network_v2.k3s_network.id
  }

  user_data = <<-EOF
    #cloud-config
    package_update: true
    package_upgrade: true
    packages:
      - curl
      - wget
    runcmd:
      - echo "Worker node ${count.index + 1} initialized" > /var/log/cloud-init-done.log
  EOF

  metadata = {
    role         = "worker"
    cluster_name = var.cluster_name
  }
}

# Floating IPs para workers
resource "openstack_networking_floatingip_v2" "k3s_worker_fip" {
  count = var.worker_count
  pool  = "Ext-Net"
}

resource "openstack_compute_floatingip_associate_v2" "k3s_worker_fip_assoc" {
  count       = var.worker_count
  floating_ip = openstack_networking_floatingip_v2.k3s_worker_fip[count.index].address
  instance_id = openstack_compute_instance_v2.k3s_worker[count.index].id
}
