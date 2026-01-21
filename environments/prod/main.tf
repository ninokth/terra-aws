# Production Environment
# Uses AWS NAT Gateway (managed, high availability, ~$40/month)

provider "aws" {
  region              = var.region
  allowed_account_ids = var.allowed_account_ids
  # Credentials come from AWS_PROFILE / env vars / instance role.
}

module "terraform_ws" {
  source = "../../terraform_ws"

  # Core settings
  name_prefix   = var.name_prefix
  admin_ip_cidr = var.admin_ip_cidr

  # Tagging (override defaults for your organization)
  project = var.project
  owner   = var.owner

  # Network settings
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  availability_zone   = var.availability_zone

  # Compute settings
  ssh_public_key_path   = var.ssh_public_key_path
  bastion_instance_type = var.bastion_instance_type
  private_instance_type = var.private_instance_type
  bastion_ami_id        = var.bastion_ami_id

  # NAT mode - HARDCODED for production
  # AWS managed NAT Gateway for high availability
  use_nat_gateway = true

  # Production safety settings
  skip_apt_upgrade     = var.skip_apt_upgrade
  egress_allowed_cidrs = var.egress_allowed_cidrs

  # VPC Flow Logs encryption (recommended for production compliance)
  flow_logs_kms_key_arn = var.flow_logs_kms_key_arn

  # Environment name for resource tagging
  environment = "prod"
}
