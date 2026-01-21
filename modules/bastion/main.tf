# Data source: Find latest Ubuntu 24.04 LTS AMI
# Only used when var.ami_id is not set
# Ubuntu 24.04 LTS (Noble Numbat) - supported until April 2029
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

# Bastion EC2 Instance
resource "aws_instance" "bastion" {
  # Use pinned AMI if provided, otherwise use latest Ubuntu 24.04 LTS
  ami                    = var.ami_id != null ? var.ami_id : data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]

  # Production hardening: EBS optimization and detailed monitoring
  ebs_optimized = true
  monitoring    = true

  # IAM instance profile for SSM and CloudWatch (if provided)
  iam_instance_profile = var.iam_instance_profile

  # Disable source/destination check only if bastion is doing NAT
  # When using AWS NAT Gateway, source_dest_check can remain enabled (default)
  source_dest_check = var.enable_nat ? false : true

  # User data: Use NAT config when enable_nat=true, otherwise basic setup
  user_data = var.enable_nat ? local.nat_user_data : local.basic_user_data

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
  # Note: user_data changes are ignored by default. To force replacement on
  # user_data changes, taint the instance: terraform taint module.bastion.aws_instance.bastion
  lifecycle {
    prevent_destroy = false
    ignore_changes  = [user_data]
  }

  tags = local.instance_tags
}

# Elastic IP for Bastion (stable public IP)
resource "aws_eip" "bastion" {
  domain   = "vpc"
  instance = aws_instance.bastion.id

  # Lifecycle rules - prevent loss of stable public IP
  # Note: prevent_destroy cannot use variables in Terraform.
  lifecycle {
    prevent_destroy = false
  }

  tags = local.eip_tags
}
