# SSH Key Pair for EC2 instance access
resource "aws_key_pair" "main" {
  key_name   = "${var.name_prefix}-key"
  public_key = file(pathexpand(var.ssh_public_key_path))

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ssh-key"
  })
}
