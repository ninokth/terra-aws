output "key_pair_name" {
  description = "Name of the SSH key pair"
  value       = aws_key_pair.main.key_name
}

output "key_pair_id" {
  description = "ID of the SSH key pair"
  value       = aws_key_pair.main.id
}

output "key_pair_fingerprint" {
  description = "Fingerprint of the SSH key pair"
  value       = aws_key_pair.main.fingerprint
}
