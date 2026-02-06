<<<<<<< HEAD
=======
# Provider OVH
>>>>>>> 8306258 (feat: añadir infraestructura K3s en OVH con ArgoCD)
provider "ovh" {
  endpoint           = var.ovh_endpoint
  application_key    = var.ovh_application_key
  application_secret = var.ovh_application_secret
  consumer_key       = var.ovh_consumer_key
}

<<<<<<< HEAD
provider "openstack" {
  alias        = "ovh"
  user_name    = var.openstack_username
  tenant_id    = var.openstack_tenant_id
  password     = var.openstack_password
  auth_url     = "https://auth.cloud.ovh.eu/v3.0"
  region       = "GRA11"  # ← CAMBIA ESTO POR TU REGIÓN
  domain_name  = "default"
=======
# Provider OpenStack para OVH Public Cloud
# Basado en: https://breadnet.co.uk/terraform-ovh-openstack/
provider "openstack" {
  auth_url    = "https://auth.cloud.ovh.net/v3"
  domain_name = "default"
  tenant_name = var.openstack_tenant_id
  user_name   = var.openstack_username
  password    = var.openstack_password
  region      = var.region
>>>>>>> 8306258 (feat: añadir infraestructura K3s en OVH con ArgoCD)
}
