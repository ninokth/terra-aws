# Phase 0: Read-only validation
data "aws_caller_identity" "current" {}

# Phase 1: VPC and Network Foundation

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

# Internet Gateway for public subnet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

# Public Subnet (10.22.5.0/24)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name_prefix}-public-subnet"
    Type = "public"
  }
}

# Private Subnet (10.22.6.0/24)
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.availability_zone

  tags = {
    Name = "${var.name_prefix}-private-subnet"
    Type = "private"
  }
}

# Route Table for Public Subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.name_prefix}-public-rt"
  }
}

# Route Table for Private Subnet (no internet route yet - will be added in Phase 5)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-private-rt"
  }
}

# Associate Public Subnet with Public Route Table
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Associate Private Subnet with Private Route Table
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# Phase 2: Security Groups

# Security Group for Bastion Host (pub_host-01)
resource "aws_security_group" "bastion" {
  name        = "${var.name_prefix}-bastion-sg"
  description = "Security group for bastion host (pub_host-01) - SSH access from admin IP only"
  vpc_id      = aws_vpc.main.id

  # Ingress: SSH from admin IP only
  ingress {
    description = "SSH from admin workstation"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_ip_cidr]
  }

  # Ingress: Allow all traffic from private subnet for NAT forwarding
  ingress {
    description = "Allow traffic from private subnet for NAT"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.private_subnet_cidr]
  }

  # Egress: Allow all outbound (for updates, NAT forwarding)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-bastion-sg"
    Host = "pub_host-01"
  }
}

# Security Group for Private Host (prv_host-01)
resource "aws_security_group" "private" {
  name        = "${var.name_prefix}-private-sg"
  description = "Security group for private host (prv_host-01) - SSH access from bastion only"
  vpc_id      = aws_vpc.main.id

  # Ingress: SSH from bastion security group only
  ingress {
    description     = "SSH from bastion host"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  # Egress: Allow all outbound (for internet access via NAT)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-private-sg"
    Host = "prv_host-01"
  }
}

# Phase 3: SSH Key Pair and AMI

# SSH Key Pair for instance access
resource "aws_key_pair" "main" {
  key_name   = "${var.name_prefix}-key"
  public_key = file(pathexpand(var.ssh_public_key_path))

  tags = {
    Name = "${var.name_prefix}-ssh-key"
  }
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
  key_name               = aws_key_pair.main.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.bastion.id]

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

  depends_on = [aws_internet_gateway.main]
}

# Phase 5: Private Instance (prv_host-01) + NAT Routing

# Private EC2 Instance
resource "aws_instance" "private" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.private_instance_type
  key_name               = aws_key_pair.main.key_name
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.private.id]

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
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.bastion.primary_network_interface_id

  depends_on = [aws_instance.bastion]
}
