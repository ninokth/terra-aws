# VPC Module - Main Configuration
#
# Creates VPC with public and private subnets for bastion-NAT infrastructure.
# Extracted from terraform_ws/main.tf (TRRAWS-001-P1.1)

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Lifecycle rules for production stability
  # Note: prevent_destroy cannot use variables in Terraform.
  # Set var.prevent_destroy = true in production and validate via CI/CD.
  lifecycle {
    prevent_destroy = false
  }

  tags = merge(var.tags, {
    Name = local.vpc_name
  })
}

# Internet Gateway for public subnet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = local.igw_name
  })
}

# Public Subnet
# Note: map_public_ip_on_launch = false for security (CKV_AWS_130)
# Instances that need public IPs should use Elastic IPs for stability
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = local.public_subnet_name
    Type = local.public_subnet_type
  })
}

# Private Subnet
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.availability_zone

  tags = merge(var.tags, {
    Name = local.private_subnet_name
    Type = local.private_subnet_type
  })
}

# Route Table for Public Subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = local.default_route_cidr
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = local.public_rt_name
  })
}

# Route Table for Private Subnet (NAT route added by private-instance module)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = local.private_rt_name
  })
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

# Restrict default security group (CKV2_AWS_12)
# The default SG should have no rules - use explicit SGs instead
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  # No ingress or egress rules - this restricts all traffic on default SG
  # Resources must use explicitly defined security groups

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-default-sg-restricted"
  })
}

# VPC Flow Logs (CKV2_AWS_11)
# CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/aws/vpc/${var.name_prefix}-flow-logs"
  retention_in_days = var.flow_logs_retention_days
  kms_key_id        = var.flow_logs_kms_key_arn

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpc-flow-logs"
  })
}

# IAM Role for VPC Flow Logs
resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.name_prefix}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.name_prefix}-vpc-flow-logs-policy"
  role = aws_iam_role.flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Effect = "Allow"
        Resource = [
          aws_cloudwatch_log_group.flow_logs[0].arn,
          "${aws_cloudwatch_log_group.flow_logs[0].arn}:*"
        ]
      }
    ]
  })
}

# VPC Flow Log
resource "aws_flow_log" "main" {
  count = var.enable_flow_logs ? 1 : 0

  vpc_id                   = aws_vpc.main.id
  traffic_type             = "ALL"
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.flow_logs[0].arn
  iam_role_arn             = aws_iam_role.flow_logs[0].arn
  max_aggregation_interval = 60

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpc-flow-log"
  })
}
