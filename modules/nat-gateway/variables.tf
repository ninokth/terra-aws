# NAT Gateway Module Variables

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "public_subnet_id" {
  description = "ID of the public subnet for NAT Gateway placement"
  type        = string
}

# Note: Internet Gateway dependency is implicit via public_subnet_id
# (subnet depends on VPC, IGW depends on VPC, so ordering is handled automatically)

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
