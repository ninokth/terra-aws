# Bastion Module

Creates the bastion host with NAT functionality using nftables.

## Resources Created

- Data: AWS AMI lookup (Ubuntu 24.04 LTS)
- EC2 Instance (bastion with NAT)
- Elastic IP

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| `name_prefix` | Prefix for resource names | `string` | Yes |
| `subnet_id` | ID of the public subnet | `string` | Yes |
| `security_group_id` | ID of bastion security group | `string` | Yes |
| `key_name` | Name of SSH key pair | `string` | Yes |
| `instance_type` | EC2 instance type | `string` | No (default: t3.micro) |
| `private_subnet_cidr` | CIDR for NAT masquerade | `string` | Yes |
| `tags` | Tags to apply | `map(string)` | No |

## Outputs

| Name | Description |
|------|-------------|
| `public_ip` | Public IP of the bastion |
| `private_ip` | Private IP of the bastion |
| `instance_id` | ID of the bastion instance |
| `ami_id` | AMI ID used |

## Usage

```hcl
module "bastion" {
  source = "../modules/bastion"

  name_prefix         = "VMs_2x_public_private"
  subnet_id           = module.vpc.public_subnet_id
  security_group_id   = module.security_groups.bastion_sg_id
  key_name            = module.ssh_key.key_pair_name
  instance_type       = "t3.micro"
  private_subnet_cidr = "10.22.6.0/24"
  tags                = { Environment = "dev" }
}
```

## NAT Configuration

The bastion acts as a NAT gateway using nftables:

- `source_dest_check = false` - Allows traffic forwarding
- `net.ipv4.ip_forward = 1` - Enables kernel forwarding
- nftables masquerade rule for outbound NAT
