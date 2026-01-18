# Security Groups Module
# Manages security groups for bastion and private instances

# Security Group for Bastion Host (pub_host-01)
resource "aws_security_group" "bastion" {
  name        = "${var.name_prefix}-bastion-sg"
  description = "Security group for bastion host (pub_host-01) - SSH access from admin IP only"
  vpc_id      = var.vpc_id

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

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-bastion-sg"
    Host = "pub_host-01"
  })
}

# Security Group for Private Host (prv_host-01)
resource "aws_security_group" "private" {
  name        = "${var.name_prefix}-private-sg"
  description = "Security group for private host (prv_host-01) - SSH access from bastion only"
  vpc_id      = var.vpc_id

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

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-sg"
    Host = "prv_host-01"
  })
}
