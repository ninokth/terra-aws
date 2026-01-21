# IAM Module - Variables

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "enable_ssm" {
  description = "Enable SSM Session Manager access for EC2 instances"
  type        = bool
  default     = true
}

variable "enable_cloudwatch" {
  description = "Enable CloudWatch agent for metrics and logs"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
