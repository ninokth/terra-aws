# 1. Read-only validation
data "aws_caller_identity" "current" {}

# 2. VPC and Network Foundation
module "vpc" {
  source = "../modules/vpc"

  name_prefix              = var.name_prefix
  vpc_cidr                 = var.vpc_cidr
  public_subnet_cidr       = var.public_subnet_cidr
  private_subnet_cidr      = var.private_subnet_cidr
  availability_zone        = var.availability_zone
  enable_flow_logs         = var.enable_flow_logs
  flow_logs_retention_days = var.flow_logs_retention_days
  flow_logs_kms_key_arn    = var.flow_logs_kms_key_arn
  tags                     = local.common_tags
}

# 3. Security Groups

module "security_groups" {
  source = "../modules/security-groups"

  name_prefix          = var.name_prefix
  vpc_id               = module.vpc.vpc_id
  admin_ip_cidr        = var.admin_ip_cidr
  private_subnet_cidr  = var.private_subnet_cidr
  bastion_nat_enabled  = !var.use_nat_gateway # Disable NAT rules if using NAT Gateway
  egress_allowed_cidrs = var.egress_allowed_cidrs
  tags                 = local.common_tags
}

# 4. SSH Key Pair and AMI

module "ssh_key" {
  source = "../modules/ssh-key"

  name_prefix         = var.name_prefix
  ssh_public_key_path = var.ssh_public_key_path
  tags                = local.common_tags
}

# 5. IAM Role and Instance Profile for EC2 (optional but recommended)
module "iam" {
  count  = var.enable_iam_role ? 1 : 0
  source = "../modules/iam"

  name_prefix       = var.name_prefix
  enable_ssm        = var.enable_ssm
  enable_cloudwatch = var.enable_cloudwatch_agent
  tags              = local.common_tags
}

# 6. NAT Gateway (production mode - when use_nat_gateway = true)

module "nat_gateway" {
  count  = var.use_nat_gateway ? 1 : 0
  source = "../modules/nat-gateway"

  name_prefix      = var.name_prefix
  public_subnet_id = module.vpc.public_subnet_id
  tags             = local.common_tags
}

# 7. Bastion Instance (pub_host-01)
# - With nftables NAT when use_nat_gateway = false (development mode)
# - Jump host only when use_nat_gateway = true (production mode)

module "bastion" {
  source = "../modules/bastion"

  name_prefix          = var.name_prefix
  subnet_id            = module.vpc.public_subnet_id
  security_group_id    = module.security_groups.bastion_sg_id
  key_name             = module.ssh_key.key_pair_name
  instance_type        = var.bastion_instance_type
  private_subnet_cidr  = var.private_subnet_cidr
  enable_nat           = !var.use_nat_gateway # Disable NAT if using NAT Gateway
  ami_id               = var.bastion_ami_id   # null = use latest Ubuntu 24.04 LTS
  skip_apt_upgrade     = var.skip_apt_upgrade
  iam_instance_profile = var.enable_iam_role ? module.iam[0].instance_profile_name : null
  tags                 = local.common_tags
}

# 8. Private Instance (prv_host-01) + NAT Routing
# Routes via bastion NAT (dev) or NAT Gateway (prod) depending on use_nat_gateway

module "private_instance" {
  source = "../modules/private-instance"

  name_prefix       = var.name_prefix
  subnet_id         = module.vpc.private_subnet_id
  security_group_id = module.security_groups.private_sg_id
  key_name          = module.ssh_key.key_pair_name
  instance_type     = var.private_instance_type
  ami_id            = module.bastion.ami_id
  route_table_id    = module.vpc.private_route_table_id

  # NAT routing - either via bastion or NAT Gateway
  create_bastion_nat_route = !var.use_nat_gateway
  nat_network_interface_id = var.use_nat_gateway ? null : module.bastion.primary_network_interface_id
  nat_gateway_id           = var.use_nat_gateway ? module.nat_gateway[0].nat_gateway_id : null

  skip_apt_upgrade     = var.skip_apt_upgrade
  iam_instance_profile = var.enable_iam_role ? module.iam[0].instance_profile_name : null
  tags                 = local.common_tags
}
