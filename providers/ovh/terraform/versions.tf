terraform {
  required_version = ">= 1.7.0"

  required_providers {
    ovh = {
      source  = "ovh/ovh"
<<<<<<< HEAD
      version = "~> 0.51.0"
    }
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54.0"
=======
      version = "~> 0.50"
    }
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54"
>>>>>>> 8306258 (feat: añadir infraestructura K3s en OVH con ArgoCD)
    }
  }
}
