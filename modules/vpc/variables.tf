# VPC Module - Variables

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
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
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# VPC Flow Logs configuration
variable "enable_flow_logs" {
  description = "Enable VPC flow logs for network traffic monitoring"
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "Number of days to retain VPC flow logs in CloudWatch (365 for compliance)"
  type        = number
  default     = 365
}

variable "flow_logs_kms_key_arn" {
  description = "KMS key ARN for encrypting flow logs. If null, uses default encryption."
  type        = string
  default     = null
}
