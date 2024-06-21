provider "aws" {
  region  = "eu-west-2"
  profile = "default"
}

# RSA key of size 4096 bits
resource "tls_private_key" "keypair-1" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
# creating private key
resource "local_file" "keypair-1" {
  content         = tls_private_key.keypair-1.private_key_pem
  filename        = "prom.pem"
  file_permission = 600
}
# creating an Ec2 keypair
resource "aws_key_pair" "keypair" {
  key_name   = "prom-keypair"
  public_key = tls_private_key.keypair-1.public_key_openssh
}
# creating Ec2 for docker Vault
resource "aws_instance" "prom_graf" {
  ami                         = "ami-053a617c6207ecc7b" // ubuntu
  instance_type               = "t2.medium"
  key_name                    = aws_key_pair.keypair.id
  vpc_security_group_ids      = [aws_security_group.prom_graf_sg.id]
  associate_public_ip_address = true
  user_data                   = templatefile("./install.sh", {
    nginx_webserver_ip = aws_instance.ec2.public_ip
  }) 
  depends_on = [aws_instance.ec2]

  tags = {
    Name = "prom-server"
  }
}
# creating Ec2 for target server
resource "aws_instance" "ec2" {
  ami                         = "ami-053a617c6207ecc7b" // ubuntu
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.keypair.id
  vpc_security_group_ids      = [aws_security_group.target_server_sg.id]
  associate_public_ip_address = true
  user_data                   = file("./install2.sh")

  tags = {
    Name = "ec2-instance"
  }
}

# security group for prometheus and grafana
resource "aws_security_group" "prom_graf_sg" {
  name        = "prom_graf_sg"
  description = "Allow Inbound Traffic"

  ingress {
    description = "prometheus_job_port"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "ssh access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "node_exporter_port"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "grafana_port"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }
  tags = {
    Name = "prom_graf_sg"
  }
}
# security group for maven
resource "aws_security_group" "target_server_sg" {
  name        = "target_server_sg"
  description = "Allow Inbound Traffic"

  ingress {
    description = "ssh access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "node_exporter_port"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }
  tags = {
    Name = "target_server_sg"
  }
}

output "prom_graf-ip" {
  value = aws_instance.prom_graf.public_ip
}

output "ec2-ip" {
  value = aws_instance.ec2.public_ip
}