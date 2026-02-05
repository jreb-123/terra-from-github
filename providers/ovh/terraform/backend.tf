terraform {
  required_version = ">= 1.7.0"

  required_providers {
    ovh = {
      source  = "ovh/ovh"
      version = "~> 0.35"
    }
  }

  # Backend local por ahora (puedes cambiarlo a S3 compatible)
  # backend "s3" {
  #   bucket                      = "terraform-state"
  #   key                         = "ovh/k3s-cluster.tfstate"
  #   region                      = "gra"
  #   endpoint                    = "s3.gra.io.cloud.ovh.net"
  #   skip_credentials_validation = true
  #   skip_region_validation      = true
  # }
}
