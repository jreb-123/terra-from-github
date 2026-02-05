# Provider OVH para gestión de cuenta
provider "ovh" {
  endpoint           = var.ovh_endpoint
  application_key    = var.ovh_application_key
  application_secret = var.ovh_application_secret
  consumer_key       = var.ovh_consumer_key
}

# Provider OpenStack para crear instancias en OVH Public Cloud
provider "openstack" {
  auth_url    = "https://auth.cloud.ovh.net/v3/"
  domain_name = "default"
  tenant_id   = var.openstack_tenant_id
  user_name   = var.openstack_username
  password    = var.openstack_password
  region      = var.region
}
