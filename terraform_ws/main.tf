# 1. Read-only validation
data "aws_caller_identity" "current" {}

# 2. VPC and Network Foundation
module "vpc" {
  source = "../modules/vpc"

  name_prefix         = var.name_prefix
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  availability_zone   = var.availability_zone
  tags                = local.common_tags
}

# 3. Security Groups

module "security_groups" {
  source = "../modules/security-groups"

  name_prefix         = var.name_prefix
  vpc_id              = module.vpc.vpc_id
  admin_ip_cidr       = var.admin_ip_cidr
  private_subnet_cidr = var.private_subnet_cidr
  tags                = local.common_tags
}

# 4. SSH Key Pair and AMI

module "ssh_key" {
  source = "../modules/ssh-key"

  name_prefix         = var.name_prefix
  ssh_public_key_path = var.ssh_public_key_path
  tags                = local.common_tags
}

# 5. Bastion Instance (pub_host-01) with nftables NAT

module "bastion" {
  source = "../modules/bastion"

  name_prefix         = var.name_prefix
  subnet_id           = module.vpc.public_subnet_id
  security_group_id   = module.security_groups.bastion_sg_id
  key_name            = module.ssh_key.key_pair_name
  instance_type       = var.bastion_instance_type
  private_subnet_cidr = var.private_subnet_cidr
  tags                = local.common_tags
}

# 6. Private Instance (prv_host-01) + NAT Routing

module "private_instance" {
  source = "../modules/private-instance"

  name_prefix              = var.name_prefix
  subnet_id                = module.vpc.private_subnet_id
  security_group_id        = module.security_groups.private_sg_id
  key_name                 = module.ssh_key.key_pair_name
  instance_type            = var.private_instance_type
  ami_id                   = module.bastion.ami_id
  route_table_id           = module.vpc.private_route_table_id
  nat_network_interface_id = module.bastion.primary_network_interface_id
  tags                     = local.common_tags
}
