variable "aws_region" {
  description = "AWS region to deploy the VPN server"
  type        = string
  default     = "eu-west-3"
}

variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
  default     = "wireguard-vpn"
}

variable "dns_servers" {
  description = "DNS servers for WireGuard clients"
  type        = string
  default     = "1.1.1.1, 1.0.0.1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPN subnet"
  type        = string
  default     = "192.168.100.0/24"
}

variable "instance_type" {
  description = "EC2 instance type (must be Free Tier eligible)"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Name for the SSH key pair"
  type        = string
  default     = "wireguard-vpn-key"
}

variable "server_port" {
  description = "WireGuard server port"
  type        = number
  default     = 51820
}

variable "client_count" {
  description = "Number of client configurations to generate"
  type        = number
  default     = 5
}
