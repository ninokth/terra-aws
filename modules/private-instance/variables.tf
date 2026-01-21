variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "subnet_id" {
  description = "ID of the private subnet"
  type        = string
}

variable "security_group_id" {
  description = "ID of the private security group"
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

variable "ami_id" {
  description = "AMI ID for the instance"
  type        = string
}

variable "route_table_id" {
  description = "ID of the private route table"
  type        = string
}

variable "nat_network_interface_id" {
  description = "Network interface ID of the bastion (for bastion NAT mode)"
  type        = string
  default     = null
}

variable "create_bastion_nat_route" {
  description = "Create NAT route via bastion (false when using AWS NAT Gateway)"
  type        = bool
  default     = true
}

variable "nat_gateway_id" {
  description = "NAT Gateway ID (used when create_bastion_nat_route = false)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
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
