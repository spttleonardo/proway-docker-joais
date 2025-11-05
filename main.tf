# Configuração do Terraform
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Configuração do Provedor
provider "aws" {
  region = "us-east-1"
}

# === BUSCANDO RECURSOS EXISTENTES ===

# 1. Busca a VPC Existente (pelo ID)
data "aws_vpc" "main" {
  id = "vpc-06786ee7f7a163059"
}

# 2. Busca a Subnet Existente (Referenciando a VPC e a Tag Name)
data "aws_subnet" "subnet_existente" {
  vpc_id = data.aws_vpc.main.id 
  
  tags = {
    Name = "sn-lschmitt" # Use o nome EXATO
  }
}
# 3. Busca a AMI Ubuntu
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] 

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


# Security Group
resource "aws_security_group" "sg" {
  name        = "jewelry-nsg"
  description = "Allow SSH and HTTP"
  vpc_id      = data.aws_vpc.main.id 

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP (para a porta do Docker exposta 8080)"
    from_port   = 8080
    to_port     = 8080
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
    Name = "jewelry-nsg"
  }
}

# Instância EC2
resource "aws_instance" "ec2" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = data.aws_subnet.subnet_existente.id 
  vpc_security_group_ids      = [aws_security_group.sg.id] 
  associate_public_ip_address = true 

  tags = {
    Name = "ec2-docker"
  }
  

  user_data_base64 = base64encode(<<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y docker.io git
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ubuntu # Alterado para o usuário padrão do Ubuntu AMI
    
    # ... (Seu script de build do Docker)
    cd /home/ubuntu
    rm -rf proway-docker/
    git clone https://github.com/spttleonardo/proway-docker-joais
    cd proway-docker-joais/modulo7-iac_tooling
    
    docker build -t jewelry-app .
    docker run -d -p 8080:80 jewelry-app
  EOF
  )
}


output "vm_public_ip" {
  value = aws_instance.ec2.public_ip
}

output "app_url" {
  value = "http://${aws_instance.ec2.public_ip}:8080"

}
