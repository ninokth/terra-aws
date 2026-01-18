# Local values for resource configuration
# Extracted from inline tags to ensure consistency across all resources

locals {
  # Common tags applied to all resources
  common_tags = {
    Project     = "bastion-nat-demo"
    Environment = "dev"
    ManagedBy   = "terraform"
    Owner       = "infrastructure-team"
  }
}
