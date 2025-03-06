provider "aws" {
  region = "us-east-1"
}

variable "projeto" {
  description = "Nome do projeto"
  type        = string
  default     = "VExpenses"
}

variable "candidato" {
  description = "Nome do candidato"
  type        = string
  default     = "SeuNome"
}

# Adicionado: variável para CIDR de Origem SSH
variable "ssh_cidr" {
  description = "CIDR permitido para acesso SSH."
  type = string
  default = "0.0.0.0/0"
}

resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "${var.projeto}-${var.candidato}-key"
  public_key = tls_private_key.ec2_key.public_key_openssh
}

resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.projeto}-${var.candidato}-vpc"
  }
}

# SUB-REDE PÚBLICA
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true # Atribui IP público automaticamente

  tags = {
    Name = "${var.projeto}-${var.candidato}-public-subnet"
  }
}

# SUB-REDE PRIVADA
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = false # Não atribui IP público automaticamente

  tags = {
    Name = "${var.projeto}-${var.candidato}-private-subnet"
  }
}

resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "${var.projeto}-${var.candidato}-igw"
  }
}

# TABELA DE ROTAS PÚBLICA
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name = "${var.projeto}-${var.candidato}-public-route_table"
  }
}

# ASSOCIAÇÃO DA TABELA DE ROTAS PÚBLICA
resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id

  tags = {
    Name = "${var.projeto}-${var.candidato}-route_table_association"
  }
}

# IP ELÁSTICO PARA NAT GATEWAY
resource "aws_eip" "nat_eip" {
  vpc = true
  tags = {
      Name = "${var.projeto}-${var.candidato}-nat-eip"
  }
}

# NAT GATEWAY NA SUBREDE PUBLICA
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id = aws_subnet.public_subnet.id # O NAT Gateway deve estar na sub-rede pública

  tags = {
    Name = "${var.projeto}-${var.candidato}-nat-gw"
  }

  depends_on = [aws_internet_gateway.main_igw]
}

# TABELA DE ROTAS PRIVADA
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id # Usa o NAT Gateway
  }

  tags = {
    Name = "${var.projeto}-${var.candidato}-private-route_table"
  }
}

# ASSOCIAÇÃO DA TABELA DE ROTAS PRIVADA
resource "aws_route_table_association" "private_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}

# MODIFICADO: Grupo de Segurança
resource "aws_security_group" "main_sg" {
  name        = "${var.projeto}-${var.candidato}-sg"
  vpc_id      = aws_vpc.main_vpc.id

  # Regras de entrada
  ingress {
    description = "Permitir SSH a partir de CIDR específico"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr] # Modificado: uso da variável ssh_cidr
  }

  # Adicionado: Permitir HTTP
  ingress {
    description = "Permitir HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Adicionado: Permitir HTTPS
  ingress {
    description = "Permitir HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Regras de saída
  egress {
    description      = "Allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.projeto}-${var.candidato}-sg"
  }
}

data "aws_ami" "debian12" {
  most_recent = true

  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["679593333241"]
}

resource "aws_instance" "debian_ec2_public" {
  ami             = data.aws_ami.debian12.id
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.public_subnet.id
  key_name        = aws_key_pair.ec2_key_pair.key_name
  vpc_security_group_ids = [aws_security_group.main_sg.id] #  Melhoria: Usar vpc_security_group_ids ao invés de security_groups

  associate_public_ip_address = true

  root_block_device {
    volume_size           = 20
    volume_type           = "gp2"
    delete_on_termination = true
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get upgrade -y
              apt-get install -y fail2ban ufw nginx # Adicionado: Instalar fail2ban, ufw e nginx

              # Adicionado: configurar o UFW
              ufw default deny incoming
              ufw default allow outgoing
              ufw allow ssh
              ufw allow http
              ufw allow https
              ufw --force enable

              # Adicionado: configurar o fail2ban
              cat <<EOT >> /etc/fail2ban/jail.local
              [sshd]
              enabled = true
              port = 22
              filter = sshd
              logpath = /var/log/auth.log
              maxretry = 3
              bantime = 3600
              EOT
              systemctl restart fail2ban
              systemctl enable fail2ban

              # Adicionado: iniciar nginx
              systemctl start nginx
              systemctl enable nginx

              EOF

  tags = {
    Name = "${var.projeto}-${var.candidato}-ec2"
  }
}

output "private_key" {
  description = "Chave privada para acessar a instância EC2"
  value       = tls_private_key.ec2_key.private_key_pem
  sensitive   = true
}

output "ec2_public_ip" {
  description = "Endereço IP público da instância EC2"
  value       = aws_instance.debian_ec2_public.public_ip
}
