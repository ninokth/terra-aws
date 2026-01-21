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

variable "bastion_nat_enabled" {
  description = "Enable NAT-related security group rules for bastion (false when using AWS NAT Gateway)"
  type        = bool
  default     = true
}

variable "egress_allowed_cidrs" {
  description = "CIDR blocks allowed for egress traffic (HTTP/HTTPS/DNS/ICMP). Default allows all (0.0.0.0/0). For production, restrict to specific endpoints (e.g., VPC endpoints, package repos)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
