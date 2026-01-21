variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "subnet_id" {
  description = "ID of the public subnet"
  type        = string
}

variable "security_group_id" {
  description = "ID of the bastion security group"
  type        = string
}

variable "key_name" {
  description = "Name of the SSH key pair"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "private_subnet_cidr" {
  description = "CIDR of private subnet (for NAT masquerade)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "enable_nat" {
  description = "Enable NAT functionality on bastion (set to false when using AWS NAT Gateway)"
  type        = bool
  default     = true
}

variable "ami_id" {
  description = "Optional AMI ID to use. If not set, uses latest Ubuntu 24.04 LTS. Set this in production for stability."
  type        = string
  default     = null
}

variable "skip_apt_upgrade" {
  description = "Skip apt-get upgrade in user_data. Enable for production with baked AMIs to avoid boot-time drift."
  type        = bool
  default     = false
}

variable "iam_instance_profile" {
  description = "IAM instance profile name for EC2. Required for SSM access and CloudWatch metrics."
  type        = string
  default     = null
}
