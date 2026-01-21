# Security Groups Module
# Manages security groups for bastion and private instances

# Security Group for Bastion Host (pub_host-01)
# checkov:skip=CKV2_AWS_5:SG is attached to bastion EC2 via module reference
resource "aws_security_group" "bastion" {
  name        = "${var.name_prefix}-bastion-sg"
  description = "Security group for bastion host (${local.bastion_hostname}) - SSH access from admin IP only"
  vpc_id      = var.vpc_id

  # Ingress: SSH from admin IP only (always enabled)
  ingress {
    description = "SSH from admin workstation"
    from_port   = local.ssh_port
    to_port     = local.ssh_port
    protocol    = local.tcp_protocol
    cidr_blocks = [var.admin_ip_cidr]
  }

  tags = local.bastion_sg_tags
}

# Bastion SG Rules - NAT mode (when bastion_nat_enabled = true)
# These rules enable the bastion to act as a NAT gateway

resource "aws_security_group_rule" "bastion_ingress_nat" {
  count = var.bastion_nat_enabled ? 1 : 0

  security_group_id = aws_security_group.bastion.id
  type              = "ingress"
  description       = "NAT forwarding - all traffic from private subnet"
  from_port         = local.all_ports_from
  to_port           = local.all_ports_to
  protocol          = local.all_protocols
  cidr_blocks       = [var.private_subnet_cidr]
}

# checkov:skip=CKV_AWS_382:NAT gateway requires unrestricted egress for packet forwarding
resource "aws_security_group_rule" "bastion_egress_nat" {
  count = var.bastion_nat_enabled ? 1 : 0

  security_group_id = aws_security_group.bastion.id
  type              = "egress"
  description       = "NAT mode - allow all outbound for forwarding"
  from_port         = local.all_ports_from
  to_port           = local.all_ports_to
  protocol          = local.all_protocols
  cidr_blocks       = [local.all_traffic_cidr]
}

# Bastion SG Rules - Non-NAT mode (when bastion_nat_enabled = false)
# Tighter egress rules when using AWS NAT Gateway

resource "aws_security_group_rule" "bastion_egress_https" {
  count = var.bastion_nat_enabled ? 0 : 1

  security_group_id = aws_security_group.bastion.id
  type              = "egress"
  description       = "HTTPS for package updates and APIs"
  from_port         = local.https_port
  to_port           = local.https_port
  protocol          = local.tcp_protocol
  cidr_blocks       = var.egress_allowed_cidrs
}

resource "aws_security_group_rule" "bastion_egress_http" {
  count = var.bastion_nat_enabled ? 0 : 1

  security_group_id = aws_security_group.bastion.id
  type              = "egress"
  description       = "HTTP for package repositories"
  from_port         = local.http_port
  to_port           = local.http_port
  protocol          = local.tcp_protocol
  cidr_blocks       = var.egress_allowed_cidrs
}

resource "aws_security_group_rule" "bastion_egress_dns" {
  count = var.bastion_nat_enabled ? 0 : 1

  security_group_id = aws_security_group.bastion.id
  type              = "egress"
  description       = "DNS resolution (UDP)"
  from_port         = local.dns_port
  to_port           = local.dns_port
  protocol          = local.udp_protocol
  cidr_blocks       = var.egress_allowed_cidrs
}

resource "aws_security_group_rule" "bastion_egress_ssh_private" {
  count = var.bastion_nat_enabled ? 0 : 1

  security_group_id = aws_security_group.bastion.id
  type              = "egress"
  description       = "SSH to private subnet for ProxyJump"
  from_port         = local.ssh_port
  to_port           = local.ssh_port
  protocol          = local.tcp_protocol
  cidr_blocks       = [var.private_subnet_cidr]
}

# checkov:skip=CKV_AWS_382:ICMP egress configurable via egress_allowed_cidrs variable
resource "aws_security_group_rule" "bastion_egress_icmp" {
  count = var.bastion_nat_enabled ? 0 : 1

  security_group_id = aws_security_group.bastion.id
  type              = "egress"
  description       = "ICMP for ping and network diagnostics"
  from_port         = local.icmp_port
  to_port           = local.icmp_port
  protocol          = local.icmp_protocol
  cidr_blocks       = var.egress_allowed_cidrs
}

# Security Group for Private Host (prv_host-01)
# checkov:skip=CKV2_AWS_5:SG is attached to private EC2 via module reference
# checkov:skip=CKV_AWS_382:Egress configurable via egress_allowed_cidrs variable
resource "aws_security_group" "private" {
  name        = "${var.name_prefix}-private-sg"
  description = "Security group for private host (${local.private_hostname}) - SSH access from bastion only"
  vpc_id      = var.vpc_id

  # Ingress: SSH from bastion security group only
  ingress {
    description     = "SSH from bastion host"
    from_port       = local.ssh_port
    to_port         = local.ssh_port
    protocol        = local.tcp_protocol
    security_groups = [aws_security_group.bastion.id]
  }

  # Egress: Rules for private instance (outbound via NAT)
  # Use var.egress_allowed_cidrs to restrict destinations for production
  egress {
    description = "HTTPS for package updates and APIs"
    from_port   = local.https_port
    to_port     = local.https_port
    protocol    = local.tcp_protocol
    cidr_blocks = var.egress_allowed_cidrs
  }

  egress {
    description = "HTTP for package repositories"
    from_port   = local.http_port
    to_port     = local.http_port
    protocol    = local.tcp_protocol
    cidr_blocks = var.egress_allowed_cidrs
  }

  egress {
    description = "DNS resolution (UDP)"
    from_port   = local.dns_port
    to_port     = local.dns_port
    protocol    = local.udp_protocol
    cidr_blocks = var.egress_allowed_cidrs
  }

  egress {
    description = "DNS resolution (TCP for large responses)"
    from_port   = local.dns_port
    to_port     = local.dns_port
    protocol    = local.tcp_protocol
    cidr_blocks = var.egress_allowed_cidrs
  }

  egress {
    description = "ICMP for ping and network diagnostics"
    from_port   = local.icmp_port
    to_port     = local.icmp_port
    protocol    = local.icmp_protocol
    cidr_blocks = var.egress_allowed_cidrs
  }

  tags = local.private_sg_tags
}
