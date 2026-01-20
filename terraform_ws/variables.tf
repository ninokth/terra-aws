variable "region" {
  description = "AWS region (passed from root module)"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for tags (used in later phases)"
  type        = string
}

# Network variables
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.22.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet (hosts use .21-.234)"
  type        = string
  default     = "10.22.5.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for private subnet (hosts use .21-.234)"
  type        = string
  default     = "10.22.6.0/24"
}

variable "availability_zone" {
  description = "AWS availability zone for subnets"
  type        = string
  default     = "eu-north-1a"
}

# Security Group variables
variable "admin_ip_cidr" {
  description = "CIDR block for admin access to bastion (e.g., 128.199.58.89/32)"
  type        = string
  # No default - user must explicitly set their IP for security
}

# SSH Key variables
variable "ssh_public_key_path" {
  description = "Path to SSH public key (Ed25519 recommended)"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

# Bastion instance variables
variable "bastion_instance_type" {
  description = "EC2 instance type for bastion host"
  type        = string
  default     = "t3.micro"
}

# Private instance variables
variable "private_instance_type" {
  description = "EC2 instance type for private host"
  type        = string
  default     = "t3.micro"
}
