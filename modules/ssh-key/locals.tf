# Local values for ssh-key module
# Centralizes configuration to avoid hardcoded values

locals {
  # Computed resource names
  key_name     = "${var.name_prefix}-key"
  key_tag_name = "${var.name_prefix}-ssh-key"
}
