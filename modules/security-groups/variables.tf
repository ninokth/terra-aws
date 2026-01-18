# Security Groups Module Variables

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "admin_ip_cidr" {
  description = "Admin IP address for SSH access (CIDR notation)"
  type        = string
}

variable "private_subnet_cidr" {
  description = "CIDR block of the private subnet (for NAT forwarding rules)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
