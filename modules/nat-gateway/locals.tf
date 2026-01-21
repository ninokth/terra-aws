# Local values for nat-gateway module
# Centralizes configuration to avoid hardcoded values

locals {
  # Resource tags (merged with passed tags)
  eip_tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-eip"
    Role = "nat-gateway"
  })

  nat_gateway_tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-gateway"
    Role = "nat-gateway"
  })
}
