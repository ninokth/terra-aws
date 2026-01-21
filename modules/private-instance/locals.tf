# Local values for private-instance module
# Centralizes configuration to avoid hardcoded values

locals {
  # Host identification
  hostname = "prv_host-01"
  role     = "private-workload"

  # Logging configuration
  log_file = "/var/log/private-setup.log"

  # Network configuration
  default_route_cidr = "0.0.0.0/0"

  # Computed values
  hosts_entry = "127.0.0.1 ${local.hostname}"

  # Resource tags (merged with passed tags)
  instance_tags = merge(var.tags, {
    Name = "${var.name_prefix}-private"
    Host = local.hostname
    Role = local.role
  })

  # User data with noninteractive apt and retry logic
  user_data = <<-EOF
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
    echo "$(date): Private host ${local.hostname} configured"
  EOF
}
