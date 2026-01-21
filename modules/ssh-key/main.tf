# SSH Key Pair for EC2 instance access
resource "aws_key_pair" "main" {
  key_name   = local.key_name
  public_key = file(pathexpand(var.ssh_public_key_path))

  # Lifecycle rules - deletion would lock out all instances
  # Note: prevent_destroy cannot use variables in Terraform.
  # Set var.prevent_destroy = true in production and validate via CI/CD.
  lifecycle {
    prevent_destroy = false
  }

  tags = merge(var.tags, {
    Name = local.key_tag_name
  })
}
