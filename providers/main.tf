provider "aws" {
  region = var.region
  # Credentials come from AWS_PROFILE / env vars / instance role.
}

module "terraform_ws" {
  source = "../terraform_ws"

  # Core settings
  region        = var.region
  name_prefix   = var.name_prefix
  admin_ip_cidr = var.admin_ip_cidr

  # Network settings
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  availability_zone   = var.availability_zone

  # Compute settings
  ssh_public_key_path   = var.ssh_public_key_path
  bastion_instance_type = var.bastion_instance_type
  private_instance_type = var.private_instance_type
}
