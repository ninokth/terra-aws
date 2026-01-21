# NAT Gateway Module
# Provides managed AWS NAT Gateway for production workloads

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  # Note: prevent_destroy cannot use variables in Terraform.
  lifecycle {
    prevent_destroy = false
  }

  tags = local.eip_tags
}

# NAT Gateway in public subnet
# Note: Dependency on Internet Gateway is implicit via module.vpc.internet_gateway_id
# passed from the calling module (terraform_ws/main.tf)
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = var.public_subnet_id

  # Note: prevent_destroy cannot use variables in Terraform.
  lifecycle {
    prevent_destroy = false
  }

  tags = local.nat_gateway_tags
}
