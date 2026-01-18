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

# Data source: Find latest Ubuntu 24.04 LTS AMI
# Note: Ubuntu 25.04 may not be available yet, using 24.04 LTS
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Ubuntu)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Phase 4: Bastion Instance (pub_host-01) with nftables NAT

# Bastion EC2 Instance
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.bastion_instance_type
  key_name               = module.ssh_key.key_pair_name
  subnet_id              = module.vpc.public_subnet_id
  vpc_security_group_ids = [module.security_groups.bastion_sg_id]

  # Disable source/destination check for NAT functionality
  source_dest_check = false

  # User data: Configure nftables NAT and set hostname
  user_data = <<-EOF
              #!/bin/bash
              set -e

              # Set hostname
              hostnamectl set-hostname pub_host-01
              echo "127.0.0.1 pub_host-01" >> /etc/hosts

              # Update system
              apt-get update
              apt-get upgrade -y

              # Install nftables (replaces iptables)
              apt-get install -y nftables

              # Enable IP forwarding for NAT
              echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
              sysctl -p

              # Configure nftables for NAT
              # Get primary network interface name
              IFACE=$(ip route | grep default | awk '{print $5}')

              # Create nftables NAT configuration
              cat > /etc/nftables.conf <<'NFTCONF'
              #!/usr/sbin/nft -f

              # Flush all rules
              flush ruleset

              table ip nat {
                  chain postrouting {
                      type nat hook postrouting priority srcnat; policy accept;
                      oifname "INTERFACE_NAME" masquerade
                  }
              }

              table ip filter {
                  chain input {
                      type filter hook input priority filter; policy accept;
                  }

                  chain forward {
                      type filter hook forward priority filter; policy accept;
                      # Allow forwarding from/to private subnet
                      ip saddr 10.22.6.0/24 accept
                      ct state related,established accept
                  }

                  chain output {
                      type filter hook output priority filter; policy accept;
                  }
              }
              NFTCONF

              # Replace INTERFACE_NAME placeholder with actual interface
              sed -i "s/INTERFACE_NAME/$IFACE/g" /etc/nftables.conf

              # Load nftables rules
              nft -f /etc/nftables.conf

              # Enable nftables service to persist on reboot
              systemctl enable nftables
              systemctl start nftables

              # Log completion
              echo "Bastion host pub_host-01 configured with nftables NAT" > /var/log/bastion-setup.log
              EOF

  tags = {
    Name = "${var.name_prefix}-bastion"
    Host = "pub_host-01"
    Role = "bastion-nat"
  }
}

# Elastic IP for Bastion (stable public IP)
resource "aws_eip" "bastion" {
  domain   = "vpc"
  instance = aws_instance.bastion.id

  tags = {
    Name = "${var.name_prefix}-bastion-eip"
    Host = "pub_host-01"
  }

  depends_on = [module.vpc]
}

# Phase 5: Private Instance (prv_host-01) + NAT Routing

# Private EC2 Instance
resource "aws_instance" "private" {
  ami                    = data.aws_ami.ubuntu.id
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
  network_interface_id   = aws_instance.bastion.primary_network_interface_id

  depends_on = [aws_instance.bastion]
}
