# NAT Gateway Module Outputs

output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = aws_nat_gateway.main.id
}

output "nat_gateway_public_ip" {
  description = "Public IP of the NAT Gateway"
  value       = aws_eip.nat.public_ip
}

output "eip_allocation_id" {
  description = "Allocation ID of the Elastic IP"
  value       = aws_eip.nat.allocation_id
}
