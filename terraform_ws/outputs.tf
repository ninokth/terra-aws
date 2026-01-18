# Phase 0 outputs
output "account_id" {
  value       = data.aws_caller_identity.current.account_id
  description = "AWS Account ID detected by Terraform"
}

output "arn" {
  value       = data.aws_caller_identity.current.arn
  description = "Caller ARN detected by Terraform (IAM user or assumed role)"
}

# Phase 1 outputs (from VPC module)
output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "ID of the VPC"
}

output "vpc_cidr" {
  value       = module.vpc.vpc_cidr_block
  description = "CIDR block of the VPC"
}

output "public_subnet_id" {
  value       = module.vpc.public_subnet_id
  description = "ID of the public subnet"
}

output "private_subnet_id" {
  value       = module.vpc.private_subnet_id
  description = "ID of the private subnet"
}

output "internet_gateway_id" {
  value       = module.vpc.internet_gateway_id
  description = "ID of the internet gateway"
}

output "public_route_table_id" {
  value       = module.vpc.public_route_table_id
  description = "ID of the public route table"
}

output "private_route_table_id" {
  value       = module.vpc.private_route_table_id
  description = "ID of the private route table"
}

# Phase 2 outputs (from Security Groups module)
output "bastion_sg_id" {
  value       = module.security_groups.bastion_sg_id
  description = "ID of the bastion security group"
}

output "private_sg_id" {
  value       = module.security_groups.private_sg_id
  description = "ID of the private security group"
}

# Phase 3 outputs (from SSH Key module)
output "key_pair_name" {
  value       = module.ssh_key.key_pair_name
  description = "Name of the SSH key pair"
}

output "ami_id" {
  value       = module.bastion.ami_id
  description = "ID of the Ubuntu AMI"
}

output "ami_name" {
  value       = module.bastion.ami_name
  description = "Name of the Ubuntu AMI"
}

# Phase 4 outputs (from Bastion module)
output "bastion_instance_id" {
  value       = module.bastion.instance_id
  description = "ID of the bastion instance"
}

output "bastion_public_ip" {
  value       = module.bastion.public_ip
  description = "Elastic IP of the bastion host"
}

output "bastion_private_ip" {
  value       = module.bastion.private_ip
  description = "Private IP of the bastion host"
}

# Phase 5 outputs
output "private_instance_id" {
  value       = aws_instance.private.id
  description = "ID of the private instance"
}

output "private_instance_private_ip" {
  value       = aws_instance.private.private_ip
  description = "Private IP of the private host"
}
