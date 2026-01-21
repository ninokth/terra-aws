output "public_ip" {
  description = "Public IP address of the bastion (Elastic IP)"
  value       = aws_eip.bastion.public_ip
}

output "private_ip" {
  description = "Private IP address of the bastion"
  value       = aws_instance.bastion.private_ip
}

output "instance_id" {
  description = "ID of the bastion instance"
  value       = aws_instance.bastion.id
}

output "ami_id" {
  description = "AMI ID used for the bastion (pinned or latest Ubuntu 24.04 LTS)"
  value       = aws_instance.bastion.ami
}

output "ami_source" {
  description = "Indicates whether AMI is pinned or from dynamic lookup"
  value       = var.ami_id != null ? "pinned" : "latest_lookup"
}

output "ami_name" {
  description = "AMI name (only accurate when ami_source is 'latest_lookup'; shows lookup result when pinned)"
  value       = data.aws_ami.ubuntu.name
}

output "primary_network_interface_id" {
  description = "Primary network interface ID of the bastion (for NAT route)"
  value       = aws_instance.bastion.primary_network_interface_id
}
