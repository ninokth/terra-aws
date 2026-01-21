# Production Environment Outputs

# Identity outputs
output "account_id" {
  value       = module.terraform_ws.account_id
  description = "AWS Account ID detected by Terraform"
  sensitive   = true
}

output "arn" {
  value       = module.terraform_ws.arn
  description = "Caller ARN detected by Terraform (IAM user or assumed role)"
}

# Environment info
output "environment" {
  value       = "prod"
  description = "Environment name"
}

output "nat_mode" {
  value       = module.terraform_ws.nat_mode
  description = "NAT mode in use (nat-gateway for prod)"
}

# VPC outputs
output "vpc_id" {
  value       = module.terraform_ws.vpc_id
  description = "ID of the VPC"
}

output "vpc_cidr" {
  value       = module.terraform_ws.vpc_cidr
  description = "CIDR block of the VPC"
}

output "public_subnet_id" {
  value       = module.terraform_ws.public_subnet_id
  description = "ID of the public subnet"
}

output "private_subnet_id" {
  value       = module.terraform_ws.private_subnet_id
  description = "ID of the private subnet"
}

output "internet_gateway_id" {
  value       = module.terraform_ws.internet_gateway_id
  description = "ID of the internet gateway"
}

output "public_route_table_id" {
  value       = module.terraform_ws.public_route_table_id
  description = "ID of the public route table"
}

output "private_route_table_id" {
  value       = module.terraform_ws.private_route_table_id
  description = "ID of the private route table"
}

# Security Groups outputs
output "bastion_sg_id" {
  value       = module.terraform_ws.bastion_sg_id
  description = "ID of the bastion security group"
}

output "private_sg_id" {
  value       = module.terraform_ws.private_sg_id
  description = "ID of the private security group"
}

# SSH Key and AMI outputs
output "key_pair_name" {
  value       = module.terraform_ws.key_pair_name
  description = "Name of the SSH key pair"
}

output "ami_id" {
  value       = module.terraform_ws.ami_id
  description = "ID of the Ubuntu AMI"
}

output "ami_name" {
  value       = module.terraform_ws.ami_name
  description = "Name of the Ubuntu AMI"
}

# Bastion outputs
output "bastion_instance_id" {
  value       = module.terraform_ws.bastion_instance_id
  description = "ID of the bastion instance"
}

output "bastion_public_ip" {
  value       = module.terraform_ws.bastion_public_ip
  description = "Elastic IP of the bastion host (use this for SSH)"
}

output "bastion_private_ip" {
  value       = module.terraform_ws.bastion_private_ip
  description = "Private IP of the bastion host"
}

# Private Instance outputs
output "private_instance_id" {
  value       = module.terraform_ws.private_instance_id
  description = "ID of the private instance"
}

output "private_instance_private_ip" {
  value       = module.terraform_ws.private_instance_private_ip
  description = "Private IP of the private host (access via bastion ProxyJump)"
}

# NAT Gateway outputs
output "nat_gateway_id" {
  value       = module.terraform_ws.nat_gateway_id
  description = "ID of the NAT Gateway"
}

output "nat_gateway_public_ip" {
  value       = module.terraform_ws.nat_gateway_public_ip
  description = "Public IP of the NAT Gateway (outbound traffic exits via this IP)"
}
