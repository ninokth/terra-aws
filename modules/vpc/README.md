# VPC Module

Creates a VPC with public and private subnets for the bastion-NAT infrastructure.

## Resources Created

- VPC
- Internet Gateway
- Public Subnet
- Private Subnet
- Public Route Table (with IGW route)
- Private Route Table
- Route Table Associations

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| `name_prefix` | Prefix for resource names | `string` | Yes |
| `vpc_cidr` | CIDR block for VPC | `string` | No (default: 10.22.0.0/16) |
| `public_subnet_cidr` | CIDR for public subnet | `string` | No (default: 10.22.5.0/24) |
| `private_subnet_cidr` | CIDR for private subnet | `string` | No (default: 10.22.6.0/24) |
| `availability_zone` | AZ for subnets | `string` | Yes |
| `tags` | Tags to apply | `map(string)` | No |

## Outputs

| Name | Description |
|------|-------------|
| `vpc_id` | ID of the VPC |
| `public_subnet_id` | ID of the public subnet |
| `private_subnet_id` | ID of the private subnet |
| `public_route_table_id` | ID of the public route table |
| `private_route_table_id` | ID of the private route table |
| `internet_gateway_id` | ID of the internet gateway |

## Usage

```hcl
module "vpc" {
  source = "../modules/vpc"

  name_prefix         = "VMs_2x_public_private"
  vpc_cidr            = "10.22.0.0/16"
  public_subnet_cidr  = "10.22.5.0/24"
  private_subnet_cidr = "10.22.6.0/24"
  availability_zone   = "eu-north-1a"
  tags                = { Environment = "dev" }
}
```
