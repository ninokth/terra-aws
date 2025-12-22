provider "aws" {
  region = var.region
  # Credentials come from AWS_PROFILE / env vars / instance role.
}

module "terraform_ws" {
  source        = "../terraform_ws"
  region        = var.region
  name_prefix   = var.name_prefix
  admin_ip_cidr = var.admin_ip_cidr
}
