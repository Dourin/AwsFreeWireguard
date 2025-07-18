# AMI ID for Ubuntu 22.04 LTS in different regions
locals {
  ubuntu_amis = {
    "eu-west-3"      = "ami-045a8ab02aadf4f88" # Ubuntu 22.04 LTS
    "eu-central-1"   = "ami-0745b7d4092315796" # Ubuntu 22.04 LTS
    "us-east-1"      = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS
    "us-west-2"      = "ami-0ea3c35c5c3284d82" # Ubuntu 22.04 LTS
    "ap-southeast-1" = "ami-0df7a207adb9748c7" # Ubuntu 22.04 LTS
    "ap-northeast-1" = "ami-03f4fa076d2981b45" # Ubuntu 22.04 LTS
  }
}

# Generate SSH key pair
resource "tls_private_key" "wireguard_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "wireguard_key" {
  key_name   = var.key_name
  public_key = tls_private_key.wireguard_key.public_key_openssh
}

# Create VPC
resource "aws_vpc" "wireguard_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "wireguard-vpc"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "wireguard_igw" {
  vpc_id = aws_vpc.wireguard_vpc.id

  tags = {
    Name = "wireguard-igw"
  }
}

# Create public subnet
resource "aws_subnet" "wireguard_subnet" {
  vpc_id                  = aws_vpc.wireguard_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "wireguard-subnet"
  }
}

# Get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# Create route table
resource "aws_route_table" "wireguard_rt" {
  vpc_id = aws_vpc.wireguard_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.wireguard_igw.id
  }

  tags = {
    Name = "wireguard-rt"
  }
}

# Associate route table with subnet
resource "aws_route_table_association" "wireguard_rta" {
  subnet_id      = aws_subnet.wireguard_subnet.id
  route_table_id = aws_route_table.wireguard_rt.id
}

# Security Group for WireGuard
resource "aws_security_group" "wireguard" {
  name_prefix = "wireguard-"
  description = "Security group for WireGuard VPN server"
  vpc_id      = aws_vpc.wireguard_vpc.id

  # WireGuard port
  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wireguard-security-group"
  }
}

# User data script to configure WireGuard
locals {
  user_data = base64encode(file("${path.module}/user_data.sh"))
}

# EC2 Instance
resource "aws_instance" "wireguard" {
  ami                    = lookup(local.ubuntu_amis, var.aws_region, "ami-045a8ab02aadf4f88")
  instance_type          = var.instance_type
  key_name               = aws_key_pair.wireguard_key.key_name
  subnet_id              = aws_subnet.wireguard_subnet.id
  vpc_security_group_ids = [aws_security_group.wireguard.id]

  user_data = local.user_data

  tags = {
    Name = "wireguard-vpn-server"
  }
}

# Save SSH private key for connection
resource "local_file" "ssh_key" {
  content         = tls_private_key.wireguard_key.private_key_pem
  filename        = "${path.module}/ssh_key.pem"
  file_permission = "0600"
}
