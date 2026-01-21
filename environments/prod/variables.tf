# Production Environment Variables
# Note: use_nat_gateway is NOT a variable here - it's hardcoded to true in main.tf

variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-north-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.region))
    error_message = "region must be a valid AWS region format (e.g., eu-north-1, us-east-1)."
  }
}

variable "allowed_account_ids" {
  description = "List of AWS account IDs where this configuration can be applied. Set to your account ID for safety."
  type        = list(string)
  # No default - must be set in terraform.tfvars for safety

  validation {
    condition     = length(var.allowed_account_ids) > 0 && alltrue([for id in var.allowed_account_ids : can(regex("^[0-9]{12}$", id))])
    error_message = "allowed_account_ids must contain at least one valid 12-digit AWS account ID."
  }
}

variable "name_prefix" {
  description = "Prefix used for resource names/tags"
  type        = string
  default     = "tf-prod"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.name_prefix)) && length(var.name_prefix) <= 20
    error_message = "name_prefix must start with a letter, contain only lowercase letters, numbers, and hyphens, and be 20 characters or less."
  }
}

# Tagging variables (override defaults for your organization)
variable "project" {
  description = "Project name for resource tagging and cost allocation"
  type        = string
  default     = "bastion-nat-demo"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.project)) && length(var.project) <= 50
    error_message = "project must start with a letter and contain only alphanumeric characters and hyphens."
  }
}

variable "owner" {
  description = "Owner name/team for resource tagging"
  type        = string
  default     = "infrastructure-team"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.owner)) && length(var.owner) <= 50
    error_message = "owner must start with a letter and contain only alphanumeric characters and hyphens."
  }
}

variable "admin_ip_cidr" {
  description = "CIDR block for admin access to bastion host (e.g., 128.199.58.89/32)"
  type        = string
  # No default - must be set in terraform.tfvars for security

  validation {
    condition     = can(cidrhost(var.admin_ip_cidr, 0))
    error_message = "admin_ip_cidr must be a valid CIDR block (e.g., 192.168.1.0/24 or 10.0.0.1/32)."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.23.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block."
  }
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.23.5.0/24"

  validation {
    condition     = can(cidrhost(var.public_subnet_cidr, 0))
    error_message = "public_subnet_cidr must be a valid CIDR block."
  }
}

variable "private_subnet_cidr" {
  description = "CIDR block for private subnet"
  type        = string
  default     = "10.23.6.0/24"

  validation {
    condition     = can(cidrhost(var.private_subnet_cidr, 0))
    error_message = "private_subnet_cidr must be a valid CIDR block."
  }
}

variable "availability_zone" {
  description = "AWS availability zone for subnets"
  type        = string
  default     = "eu-north-1a"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9][a-z]$", var.availability_zone))
    error_message = "availability_zone must be a valid AWS AZ format (e.g., eu-north-1a, us-east-1b)."
  }
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key file (Ed25519 recommended)"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"

  validation {
    condition     = can(regex("\\.(pub)$", var.ssh_public_key_path))
    error_message = "ssh_public_key_path must end with .pub extension."
  }
}

variable "bastion_instance_type" {
  description = "EC2 instance type for bastion host"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^[a-z][0-9]+[a-z]?\\.(nano|micro|small|medium|large|xlarge|[0-9]+xlarge)$", var.bastion_instance_type))
    error_message = "bastion_instance_type must be a valid EC2 instance type (e.g., t3.micro, t3.small, m5.large)."
  }
}

variable "private_instance_type" {
  description = "EC2 instance type for private host"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^[a-z][0-9]+[a-z]?\\.(nano|micro|small|medium|large|xlarge|[0-9]+xlarge)$", var.private_instance_type))
    error_message = "private_instance_type must be a valid EC2 instance type (e.g., t3.micro, t3.small, m5.large)."
  }
}

# AMI pinning for production stability
variable "bastion_ami_id" {
  description = "AMI ID for bastion. If null, uses latest Ubuntu 24.04 LTS. Recommended to pin for production stability."
  type        = string
  default     = null

  validation {
    condition     = var.bastion_ami_id == null || can(regex("^ami-[a-f0-9]{8,17}$", var.bastion_ami_id))
    error_message = "bastion_ami_id must be a valid AMI ID format (e.g., ami-0123456789abcdef0) or null."
  }
}

# Skip apt-get upgrade for baked AMI workflows
variable "skip_apt_upgrade" {
  description = "Skip apt-get upgrade in user_data. Recommended true for production with baked AMIs."
  type        = bool
  default     = true
}

# Security group egress restrictions for production
variable "egress_allowed_cidrs" {
  description = "CIDR blocks allowed for egress (HTTP/HTTPS/DNS/ICMP). For production, restrict to specific endpoints (e.g., VPC endpoints, package repos)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# VPC Flow Logs encryption (recommended for production)
variable "flow_logs_kms_key_arn" {
  description = "KMS key ARN for encrypting VPC flow logs. Recommended for production compliance."
  type        = string
  default     = null
}
