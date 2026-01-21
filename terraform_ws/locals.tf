# Local values for resource configuration
# Extracted from inline tags to ensure consistency across all resources

locals {
  # Common tags applied to all resources
  # Project and Owner are now configurable via variables
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = var.owner
  }
}
