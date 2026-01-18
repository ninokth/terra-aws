# Private Instance Module

Creates the private instance and NAT route through bastion.

## Resources Created

- EC2 Instance (private)
- Route (NAT via bastion)

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| `name_prefix` | Prefix for resource names | `string` | Yes |
| `subnet_id` | ID of the private subnet | `string` | Yes |
| `security_group_id` | ID of private security group | `string` | Yes |
| `key_name` | Name of SSH key pair | `string` | Yes |
| `instance_type` | EC2 instance type | `string` | No (default: t3.micro) |
| `ami_id` | AMI ID for the instance | `string` | Yes |
| `route_table_id` | ID of private route table | `string` | Yes |
| `nat_instance_id` | ID of bastion (NAT) instance | `string` | Yes |
| `tags` | Tags to apply | `map(string)` | No |

## Outputs

| Name | Description |
|------|-------------|
| `private_ip` | Private IP of the instance |
| `instance_id` | ID of the instance |

## Usage

```hcl
module "private_instance" {
  source = "../modules/private-instance"

  name_prefix       = "my-project"
  subnet_id         = module.vpc.private_subnet_id
  security_group_id = module.security_groups.private_sg_id
  key_name          = module.ssh_key.key_pair_name
  instance_type     = "t3.micro"
  ami_id            = module.bastion.ami_id
  route_table_id    = module.vpc.private_route_table_id
  nat_instance_id   = module.bastion.instance_id
  tags              = { Environment = "dev" }
}
```

## NAT Route

Routes all internet traffic (0.0.0.0/0) through the bastion instance.

## Status

**Pending extraction** - See [TRRAWS-001-P1.5-private-instance-module](../Notes/tickets/TRRAWS-001-P0.0-refactoring-plan/TRRAWS-001-P1/TRRAWS-001-P1.5-private-instance-module/)
