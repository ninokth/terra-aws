# Data source: Find latest Ubuntu 24.04 LTS AMI
# Note: Ubuntu 25.04 may not be available yet, using 24.04 LTS
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Ubuntu)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Bastion EC2 Instance
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]

  # Disable source/destination check for NAT functionality
  source_dest_check = false

  # User data: Configure nftables NAT and set hostname
  user_data = <<-EOF
              #!/bin/bash
              set -e

              # Set hostname
              hostnamectl set-hostname pub_host-01
              echo "127.0.0.1 pub_host-01" >> /etc/hosts

              # Update system
              apt-get update
              apt-get upgrade -y

              # Install nftables (replaces iptables)
              apt-get install -y nftables

              # Enable IP forwarding for NAT
              echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
              sysctl -p

              # Configure nftables for NAT
              # Get primary network interface name
              IFACE=$(ip route | grep default | awk '{print $5}')

              # Create nftables NAT configuration
              cat > /etc/nftables.conf <<'NFTCONF'
              #!/usr/sbin/nft -f

              # Flush all rules
              flush ruleset

              table ip nat {
                  chain postrouting {
                      type nat hook postrouting priority srcnat; policy accept;
                      oifname "INTERFACE_NAME" masquerade
                  }
              }

              table ip filter {
                  chain input {
                      type filter hook input priority filter; policy accept;
                  }

                  chain forward {
                      type filter hook forward priority filter; policy accept;
                      # Allow forwarding from/to private subnet
                      ip saddr ${var.private_subnet_cidr} accept
                      ct state related,established accept
                  }

                  chain output {
                      type filter hook output priority filter; policy accept;
                  }
              }
              NFTCONF

              # Replace INTERFACE_NAME placeholder with actual interface
              sed -i "s/INTERFACE_NAME/$IFACE/g" /etc/nftables.conf

              # Load nftables rules
              nft -f /etc/nftables.conf

              # Enable nftables service to persist on reboot
              systemctl enable nftables
              systemctl start nftables

              # Log completion
              echo "Bastion host pub_host-01 configured with nftables NAT" > /var/log/bastion-setup.log
              EOF

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-bastion"
    Host = "pub_host-01"
    Role = "bastion-nat"
  })
}

# Elastic IP for Bastion (stable public IP)
resource "aws_eip" "bastion" {
  domain   = "vpc"
  instance = aws_instance.bastion.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-bastion-eip"
    Host = "pub_host-01"
  })
}
