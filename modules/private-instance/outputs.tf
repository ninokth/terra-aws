output "private_ip" {
  description = "Private IP address of the instance"
  value       = aws_instance.private.private_ip
}

output "instance_id" {
  description = "ID of the private instance"
  value       = aws_instance.private.id
}
