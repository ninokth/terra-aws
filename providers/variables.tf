variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-north-1"
}

variable "name_prefix" {
  description = "Prefix used for resource names/tags"
  type        = string
  default     = "tf-demo"
}

variable "admin_ip_cidr" {
  description = "CIDR block for admin access to bastion host (e.g., 128.199.58.89/32)"
  type        = string
  # No default - must be set in terraform.tfvars for security
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.22.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.22.5.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for private subnet"
  type        = string
  default     = "10.22.6.0/24"
}

variable "availability_zone" {
  description = "AWS availability zone for subnets"
  type        = string
  default     = "eu-north-1a"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key file (Ed25519 recommended)"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "bastion_instance_type" {
  description = "EC2 instance type for bastion host"
  type        = string
  default     = "t3.micro"
}

variable "private_instance_type" {
  description = "EC2 instance type for private host"
  type        = string
  default     = "t3.micro"
}
