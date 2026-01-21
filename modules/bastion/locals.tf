# Local values for bastion module
# Centralizes configuration to avoid hardcoded values

locals {
  # Host identification
  hostname = "pub_host-01"
  # Role changes based on whether NAT is enabled
  role = var.enable_nat ? "bastion-nat" : "bastion-jump"

  # Logging configuration
  log_file = "/var/log/bastion-setup.log"

  # Computed values
  hosts_entry = "127.0.0.1 ${local.hostname}"

  # Resource tags (merged with passed tags)
  instance_tags = merge(var.tags, {
    Name = "${var.name_prefix}-bastion"
    Host = local.hostname
    Role = local.role
  })

  eip_tags = merge(var.tags, {
    Name = "${var.name_prefix}-bastion-eip"
    Host = local.hostname
  })

  # Basic user_data (no NAT functionality - used when AWS NAT Gateway is enabled)
  basic_user_data = <<-EOF
    #!/bin/bash
    set -e
    exec > >(tee -a ${local.log_file}) 2>&1

    # Prevent interactive prompts during apt operations
    export DEBIAN_FRONTEND=noninteractive
    export NEEDRESTART_MODE=a

    # Set hostname
    hostnamectl set-hostname ${local.hostname}
    echo "${local.hosts_entry}" >> /etc/hosts

    # Update system with retry logic
    for i in 1 2 3; do
      apt-get update && break || sleep 10
    done
    %{if !var.skip_apt_upgrade~}
    apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade
    %{endif~}

    # Log completion
    echo "$(date): Bastion host ${local.hostname} configured (jump-only mode)"
  EOF

  # NAT user_data (full NAT functionality - development mode)
  nat_user_data = <<-EOF
    #!/bin/bash
    set -e
    exec > >(tee -a ${local.log_file}) 2>&1

    # Prevent interactive prompts during apt operations
    export DEBIAN_FRONTEND=noninteractive
    export NEEDRESTART_MODE=a

    # Set hostname
    hostnamectl set-hostname ${local.hostname}
    echo "${local.hosts_entry}" >> /etc/hosts

    # Update system with retry logic
    for i in 1 2 3; do
      apt-get update && break || sleep 10
    done
    %{if !var.skip_apt_upgrade~}
    apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade
    %{endif~}

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
    echo "$(date): Bastion host ${local.hostname} configured with nftables NAT"
  EOF
}
