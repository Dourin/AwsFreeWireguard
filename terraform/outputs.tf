output "server_public_ip" {
  description = "Public IP address of the WireGuard server"
  value       = aws_instance.wireguard.public_ip
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.wireguard.id
}

output "server_region" {
  description = "AWS region where the server is deployed"
  value       = var.aws_region
}

output "ssh_private_key" {
  description = "Private SSH key to connect to the server"
  value       = tls_private_key.wireguard_key.private_key_pem
  sensitive   = true
}

output "ssh_connection_command" {
  description = "SSH command to connect to the server"
  value       = "ssh -i ssh_key.pem ubuntu@${aws_instance.wireguard.public_ip}"
}

output "server_endpoint" {
  description = "WireGuard server endpoint"
  value       = "${aws_instance.wireguard.public_ip}:${var.server_port}"
}
