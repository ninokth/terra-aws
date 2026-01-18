# Private EC2 Instance
resource "aws_instance" "private" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]

  # User data: Set hostname
  user_data = <<-EOF
              #!/bin/bash
              set -e

              # Set hostname
              hostnamectl set-hostname prv_host-01
              echo "127.0.0.1 prv_host-01" >> /etc/hosts

              # Update system
              apt-get update
              apt-get upgrade -y

              # Log completion
              echo "Private host prv_host-01 configured" > /var/log/private-setup.log
              EOF

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private"
    Host = "prv_host-01"
    Role = "private-workload"
  })
}

# Add route to private route table for internet access via bastion NAT
resource "aws_route" "private_to_nat" {
  route_table_id         = var.route_table_id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = var.nat_network_interface_id
}
