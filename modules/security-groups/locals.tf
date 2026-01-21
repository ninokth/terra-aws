# Local values for security-groups module
# Centralizes configuration to avoid hardcoded values

locals {
  # Port definitions
  ssh_port   = 22
  http_port  = 80
  https_port = 443
  dns_port   = 53

  # Protocol definitions
  all_protocols = "-1" # AWS security group value for all protocols
  tcp_protocol  = "tcp"
  udp_protocol  = "udp"
  icmp_protocol = "icmp"

  # ICMP uses -1 for from_port/to_port to allow all ICMP types
  icmp_port = -1

  # CIDR blocks
  all_traffic_cidr = "0.0.0.0/0"

  # Port ranges for "all ports"
  all_ports_from = 0
  all_ports_to   = 0

  # Host identifiers for tags
  bastion_hostname = "pub_host-01"
  private_hostname = "prv_host-01"

  # Resource tags
  bastion_sg_tags = merge(var.tags, {
    Name = "${var.name_prefix}-bastion-sg"
    Host = local.bastion_hostname
  })

  private_sg_tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-sg"
    Host = local.private_hostname
  })
}
