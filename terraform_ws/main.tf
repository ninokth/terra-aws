# Phase 0: Read-only validation
data "aws_caller_identity" "current" {}

# Phase 1: VPC and Network Foundation
module "vpc" {
  source = "../modules/vpc"

  name_prefix         = var.name_prefix
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  availability_zone   = var.availability_zone
  tags                = local.common_tags
}

# Phase 2: Security Groups

module "security_groups" {
  source = "../modules/security-groups"

  name_prefix         = var.name_prefix
  vpc_id              = module.vpc.vpc_id
  admin_ip_cidr       = var.admin_ip_cidr
  private_subnet_cidr = var.private_subnet_cidr
  tags                = local.common_tags
}

# Phase 3: SSH Key Pair and AMI

module "ssh_key" {
  source = "../modules/ssh-key"

  name_prefix         = var.name_prefix
  ssh_public_key_path = var.ssh_public_key_path
  tags                = local.common_tags
}

# Phase 4: Bastion Instance (pub_host-01) with nftables NAT

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

# Phase 5: Private Instance (prv_host-01) + NAT Routing

# Private EC2 Instance
resource "aws_instance" "private" {
  ami                    = module.bastion.ami_id
  instance_type          = var.private_instance_type
  key_name               = module.ssh_key.key_pair_name
  subnet_id              = module.vpc.private_subnet_id
  vpc_security_group_ids = [module.security_groups.private_sg_id]

  # User data: Set hostname
  user_data = <<-EOF
              #!/bin/bash
              set -e

              # Set hostname
              hostnamectl set-hostname prv_host-01
              echo "127.0.0.1 prv_host-01" >> /etc/hosts

              # Update system
              apt-get update
              apt-get upgrade -y

              # Log completion
              echo "Private host prv_host-01 configured" > /var/log/private-setup.log
              EOF

  tags = {
    Name = "${var.name_prefix}-private"
    Host = "prv_host-01"
    Role = "private-workload"
  }
}

# Add route to private route table for internet access via bastion NAT
resource "aws_route" "private_to_nat" {
  route_table_id         = module.vpc.private_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = module.bastion.primary_network_interface_id
}
