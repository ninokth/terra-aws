variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-north-1"
}

variable "name_prefix" {
  description = "Prefix used for resource names/tags (used in later phases)"
  type        = string
  default     = "tf-demo"
}

# Phase 2: Security variables
variable "admin_ip_cidr" {
  description = "CIDR block for admin access to bastion host (e.g., 128.199.58.89/32)"
  type        = string
  # No default - must be set in terraform.tfvars for security
}
