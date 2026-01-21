# Local values for vpc module
# Centralizes configuration to avoid hardcoded values

locals {
  # Network constants
  default_route_cidr = "0.0.0.0/0"

  # Subnet types for tagging
  public_subnet_type  = "public"
  private_subnet_type = "private"

  # Computed resource names
  vpc_name            = "${var.name_prefix}-vpc"
  igw_name            = "${var.name_prefix}-igw"
  public_subnet_name  = "${var.name_prefix}-public-subnet"
  private_subnet_name = "${var.name_prefix}-private-subnet"
  public_rt_name      = "${var.name_prefix}-public-rt"
  private_rt_name     = "${var.name_prefix}-private-rt"
}
