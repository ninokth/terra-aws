# Private EC2 Instance
resource "aws_instance" "private" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]

  # Production hardening: EBS optimization and detailed monitoring
  ebs_optimized = true
  monitoring    = true

  # IAM instance profile for SSM and CloudWatch (if provided)
  iam_instance_profile = var.iam_instance_profile

  # User data from locals (with noninteractive apt and retry logic)
  user_data = local.user_data

  # Security hardening: Require IMDSv2 (disable IMDSv1)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Enforces IMDSv2
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  # Security hardening: Encrypt root volume
  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }

  # Lifecycle rules for production stability
  # Note: prevent_destroy cannot use variables in Terraform.
  # Set var.prevent_destroy = true in production and validate via CI/CD.
  # Note: user_data changes are ignored by default. To force replacement,
  # taint the instance (e.g., terraform taint module.private_instance.aws_instance.private).
  lifecycle {
    prevent_destroy = false
    ignore_changes  = [user_data]
  }

  tags = local.instance_tags
}

# Route via bastion NAT (development mode)
# Created when create_bastion_nat_route = true (dev environment)
# tflint-ignore: aws_route_not_specified_target
resource "aws_route" "private_to_bastion_nat" {
  count = var.create_bastion_nat_route ? 1 : 0

  route_table_id         = var.route_table_id
  destination_cidr_block = local.default_route_cidr
  network_interface_id   = var.nat_network_interface_id
}

# Route via AWS NAT Gateway (production mode)
# Created when create_bastion_nat_route = false (prod environment)
# tflint-ignore: aws_route_not_specified_target
resource "aws_route" "private_to_nat_gateway" {
  count = var.create_bastion_nat_route ? 0 : 1

  route_table_id         = var.route_table_id
  destination_cidr_block = local.default_route_cidr
  nat_gateway_id         = var.nat_gateway_id
}
