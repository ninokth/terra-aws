# TFLint Configuration
# https://github.com/terraform-linters/tflint
#
# Install AWS plugin: tflint --init

config {
  # Enable module inspection
  call_module_type = "local"

  # Force mode returns non-zero exit code on warnings
  force = false
}

# AWS Provider Plugin
plugin "aws" {
  enabled = true
  version = "0.32.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Terraform Language Rules
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# ============================================
# AWS-Specific Rules
# ============================================

# Ensure instance types are valid
rule "aws_instance_invalid_type" {
  enabled = true
}

# Ensure AMI IDs are valid format
rule "aws_instance_invalid_ami" {
  enabled = true
}

# Ensure security group rules have descriptions
rule "aws_security_group_rule_invalid_protocol" {
  enabled = true
}

# ============================================
# Terraform Best Practice Rules
# ============================================

# Disallow deprecated syntax
rule "terraform_deprecated_interpolation" {
  enabled = true
}

# Require description for variables
rule "terraform_documented_variables" {
  enabled = true
}

# Require description for outputs
rule "terraform_documented_outputs" {
  enabled = true
}

# Enforce naming conventions
rule "terraform_naming_convention" {
  enabled = true

  # Use snake_case for all identifiers
  format = "snake_case"

  # Custom patterns can be set per resource type
  custom_formats = {}
}

# Require version constraints for providers
rule "terraform_required_providers" {
  enabled = true
}

# Require terraform version constraint
rule "terraform_required_version" {
  enabled = true
}

# Disallow variables/locals/outputs without type
rule "terraform_typed_variables" {
  enabled = true
}

# Ensure consistent formatting (terraform fmt)
rule "terraform_standard_module_structure" {
  enabled = true
}

# Warn on unused declarations
rule "terraform_unused_declarations" {
  enabled = true
}

# Warn on unused required providers
rule "terraform_unused_required_providers" {
  enabled = true
}
