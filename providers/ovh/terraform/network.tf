# Obtener la red pública existente
data "openstack_networking_network_v2" "public" {
  name      = "Ext-Net"
  tenant_id = var.service_name
}

# Red privada para el cluster
resource "openstack_networking_network_v2" "k3s_network" {
  name           = "${var.cluster_name}-network"
  admin_state_up = true
}

# Subred privada
resource "openstack_networking_subnet_v2" "k3s_subnet" {
  name            = "${var.cluster_name}-subnet"
  network_id      = openstack_networking_network_v2.k3s_network.id
  cidr            = "192.168.1.0/24"
  ip_version      = 4
  dns_nameservers = ["1.1.1.1", "8.8.8.8"]
}

# Router
resource "openstack_networking_router_v2" "k3s_router" {
  name                = "${var.cluster_name}-router"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.public.id
}

# Interfaz del router a la subred
resource "openstack_networking_router_interface_v2" "k3s_router_interface" {
  router_id = openstack_networking_router_v2.k3s_router.id
  subnet_id = openstack_networking_subnet_v2.k3s_subnet.id
}

# Security group
resource "openstack_networking_secgroup_v2" "k3s_secgroup" {
  name        = "${var.cluster_name}-secgroup"
  description = "Security group for K3s cluster"
}

# Regla SSH
resource "openstack_networking_secgroup_rule_v2" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.k3s_secgroup.id
}

# Regla K3s API (6443)
resource "openstack_networking_secgroup_rule_v2" "k3s_api" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 6443
  port_range_max    = 6443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.k3s_secgroup.id
}

# Regla HTTP
resource "openstack_networking_secgroup_rule_v2" "http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.k3s_secgroup.id
}

# Regla HTTPS
resource "openstack_networking_secgroup_rule_v2" "https" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.k3s_secgroup.id
}

# Regla comunicación interna del cluster
resource "openstack_networking_secgroup_rule_v2" "internal" {
  direction         = "ingress"
  ethertype         = "IPv4"
  remote_group_id   = openstack_networking_secgroup_v2.k3s_secgroup.id
  security_group_id = openstack_networking_secgroup_v2.k3s_secgroup.id
}
