# Security Groups Module

Creates security groups for bastion and private instances.

## Resources Created

- Bastion Security Group (SSH from admin IP)
- Private Security Group (SSH from bastion only)

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| `name_prefix` | Prefix for resource names | `string` | Yes |
| `vpc_id` | ID of the VPC | `string` | Yes |
| `admin_ip` | Admin IP for SSH access (CIDR) | `string` | Yes |
| `tags` | Tags to apply | `map(string)` | No |

## Outputs

| Name | Description |
|------|-------------|
| `bastion_sg_id` | ID of bastion security group |
| `private_sg_id` | ID of private security group |

## Usage

```hcl
module "security_groups" {
  source = "../modules/security-groups"

  name_prefix = "my-project"
  vpc_id      = module.vpc.vpc_id
  admin_ip    = "203.0.113.0/32"
  tags        = { Environment = "dev" }
}
```

## Security Rules

### Bastion SG

- Ingress: SSH (22) from admin_ip only
- Egress: All traffic

### Private SG

- Ingress: SSH (22) from bastion SG only
- Egress: All traffic (for NAT)

## Status

**Pending extraction** - See [TRRAWS-001-P1.2-security-groups-module](../Notes/tickets/TRRAWS-001-P0.0-refactoring-plan/TRRAWS-001-P1/TRRAWS-001-P1.2-security-groups-module/)
