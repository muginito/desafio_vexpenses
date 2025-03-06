# README

Este documento descreve em detalhes o código Terraform fornecido, bem como as alterações que visam aplicar melhorias de segurança e automação.

- [Código Original](./original/main.tf)
- [Código Modificado](./modificado/main.tf)

## TOC

- [README](#readme)
  - [TOC](#toc)
  - [Visão Geral](#visão-geral)
  - [Linguagem de Configuração](#linguagem-de-configuração)
  - [Detalhes do Código Original](#detalhes-do-código-original)
    - [1. Provider](#1-provider)
    - [2. Variáveis](#2-variáveis)
    - [3. Chave Privada (`tls_private_key`)](#3-chave-privada-tls_private_key)
    - [4. Par de Chaves (`aws_key_pair`)](#4-par-de-chaves-aws_key_pair)
    - [5. VPC (`aws_vpc`)](#5-vpc-aws_vpc)
    - [6. Sub-Rede (`aws_subnet`)](#6-sub-rede-aws_subnet)
    - [7. Internet Gateway (`aws_internet_gateway`)](#7-internet-gateway-aws_internet_gateway)
    - [8. Tabela de Rotas (`aws_route_table`)](#8-tabela-de-rotas-aws_route_table)
    - [9. Associação da Tabela de Rotas (`aws_route_table_association`)](#9-associação-da-tabela-de-rotas-aws_route_table_association)
    - [10. Grupo de Segurança (`aws_security_group`)](#10-grupo-de-segurança-aws_security_group)
    - [11. AMI (`data "aws_ami"`)](#11-ami-data-aws_ami)
    - [12. Instância EC2 (`aws_instance`)](#12-instância-ec2-aws_instance)
    - [13. Outputs](#13-outputs)
  - [Alterações no Código Original](#alterações-no-código-original)
    - [Restrição de acesso SSH](#restrição-de-acesso-ssh)
    - [Separação entre sub-rede pública e privada](#separação-entre-sub-rede-pública-e-privada)
      - [Subnets (pública e privada)](#subnets-pública-e-privada)
    - [HTTP e HTTPS](#http-e-https)
    - [Modificações no script `user_data` (`fail2ban`, `ufw` e `nginx`)](#modificações-no-script-user_data-fail2ban-ufw-e-nginx)
    - [Argumento `security_groups` em `aws_instance`](#argumento-security_groups-em-aws_instance)

## Visão Geral

O código Terraform configura os seguintes recursos da infraestrutura:

1. **Provider**: AWS.
2. **Variáveis ("projeto" e "candidato")**: Variáveis para criar nomes de recursos.
3. **Key Pair**: Par de chaves para conexão SSH segura.
4. **VPC**: Rede virtual isolada na AWS.
5. **Subnet**: Sub-rede dentro da VPC.
6. **Internet Gateway**: Permite conexão entre a VPC e a Internet.
7. **Route Table**: Tabela de rotas para roteamento de tráfego.
8. **Route Table Association**: Associa a tabela de rotas à sub-rede.
9. **Security Group**: Firewall virtual para controle de entrada e saída de tráfego da instância EC2.
10. **AMI (Debian12)**: busca uma imagem do Debian 12 para a instância EC2.
11. **EC2 Instance**: A instância EC2 propriamente dita.
12. **Outputs**: Chave privada e IP público da EC2.

## Linguagem de Configuração

A Terraform é uma ferramenta de *infrastructure as code*.

A estrutura do nosso código possui blocos que definem:

- **Provider:** Plugin que configura o provedor.
- **Variables:** Define variáveis de entrada.
- **Resources:** Declara os recursos a serem criados e atribui um nome local, o qual será utilizado como referência para o recurso no código.
- **Data Sources:** Busca informações sobre recursos existentes (neste caso, a AMI do Debian).
- **Outputs:** Define valores de saída que podem ser acessados após a execução do Terraform.

## Detalhes do Código Original

[Código Original](./original/main.tf)

### 1. Provider

```terraform
provider "aws" {
  region = "us-east-1"
}
```

- `provider "aws"`: Define a AWS como provedor cloud.
- `region = "us-east-1"`: Define a [Região AWS](https://aws.amazon.com/pt/about-aws/global-infrastructure/regions_az/?p=ngi&loc=2) como `us-east-1`.

### 2. Variáveis

```terraform
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
```

- `variable "projeto"`: Variável para o nome do projeto (padrão: "VExpenses").
- `variable "candidato"`: Variável para o nome do candidato (padrão: "SeuNome").
- `type = string` e `default`: Ambas as variáveis são do tipo string e possuem valores padrão. Esses valores podem ser sobrescritos na linha de comando ou em um arquivo terraform.tfvars.
- Essas variáveis são utilizadas no código afim de criar nomes únicos para objetos da infraestrutura.

### 3. Chave Privada (`tls_private_key`)

```terraform
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
```

Gera uma chave privada RSA localmente.

- `resource "tls_private_key" "ec2_key"`: Gera uma chave privada RSA localmente.
  - `algorithm = "RSA"`: Usa o algoritmo RSA.
  - `rsa_bits = 2048`: Define o tamanho da chave como 2048 bits.

### 4. Par de Chaves (`aws_key_pair`)

```terraform
resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "${var.projeto}-${var.candidato}-key"
  public_key = tls_private_key.ec2_key.public_key_openssh
}
```

- `resource "aws_key_pair" "ec2_key_pair"`: Cria um par de chaves SSH na AWS.
  - `key_name`: Define o nome do par de chaves usando as variáveis `projeto` e `candidato`.
  - `public_key`: Envia a chave pública (gerada a partir da chave privada local) para a AWS.

### 5. VPC (`aws_vpc`)

```terraform
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.projeto}-${var.candidato}-vpc"
  }
}
```

- `resource "aws_vpc" "main_vpc"`: Cria uma VPC.
  - `cidr_block = "10.0.0.0/16"`: Define o bloco CIDR da VPC (intervalo de IPs privados).
  - `enable_dns_support = true`: Habilita o suporte a DNS.
  - `enable_dns_hostnames = true`: Habilita a atribuição de nomes de host DNS.
  - `tags`: Adiciona uma tag `Name` para identificação usando as [variáveis](#2-variáveis).

### 6. Sub-Rede (`aws_subnet`)

```terraform
resource "aws_subnet" "main_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "${var.projeto}-${var.candidato}-subnet"
  }
}
```

- `resource "aws_subnet" "main_subnet"`: Cria a sub-rede.
  - `vpc_id`: Associa a sub-rede à VPC.
  - `cidr_block = "10.0.1.0/24"`: Define o bloco CIDR da sub-rede (dentro do bloco CIDR da VPC).
  - `availability_zone = "us-east-1a"`: Especifica a [zona de disponibilidade](https://aws.amazon.com/pt/about-aws/global-infrastructure/regions_az/?p=ngi&loc=2).
  - `tags`: Adiciona uma tag `Name` para identificação usando as [variáveis](#2-variáveis).

### 7. Internet Gateway (`aws_internet_gateway`)

```terraform
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "${var.projeto}-${var.candidato}-igw"
  }
}
```

- `resource "aws_internet_gateway" "main_igw"`: Cria o Internet Gateway.
  - `vpc_id`: Anexa o Internet Gateway à VPC.
  - `tags`: Adiciona uma tag `Name` para identificação usando as [variáveis](#2-variáveis).

### 8. Tabela de Rotas (`aws_route_table`)

```terraform
resource "aws_route_table" "main_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name = "${var.projeto}-${var.candidato}-route_table"
  }
}
```

- `resource "aws_route_table" "main_route_table"`: Cria a tabela de rotas.
  - `vpc_id`: Associa a tabela de rotas à VPC.
  - `route`: Define uma rota para o tráfego da internet (0.0.0.0/0) ser direcionado ao Internet Gateway.
  - `tags`: Adiciona uma tag `Name` para identificação usando as [variáveis](#2-variáveis).

### 9. Associação da Tabela de Rotas (`aws_route_table_association`)

```terraform
resource "aws_route_table_association" "main_association" {
  subnet_id      = aws_subnet.main_subnet.id
  route_table_id = aws_route_table.main_route_table.id

  tags = {
    Name = "${var.projeto}-${var.candidato}-route_table_association"
  }
}
```

- `resource "aws_route_table_association" "main_association"`: Associa a tabela de rotas à sub-rede.

### 10. Grupo de Segurança (`aws_security_group`)

```terraform
resource "aws_security_group" "main_sg" {
  name        = "${var.projeto}-${var.candidato}-sg"
  description = "Permitir SSH de qualquer lugar e todo o tráfego de saída"
  vpc_id      = aws_vpc.main_vpc.id

  # Regras de entrada
  ingress {
    description      = "Allow SSH from anywhere"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
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
```

- `resource "aws_security_group" "main_sg"`: Cria o grupo de segurança.
  - `name`: Nome do grupo de segurança.
  - `description`: Descrição do grupo de segurança.
  - `vpc_id`: Associa o grupo de segurança à VPC.
  - `ingress`: Regras de entrada:
    - Permite tráfego SSH (porta 22) de qualquer origem (0.0.0.0/0 e ::/0).
  - `egress`: Regras de saída:
    - Permite todo o tráfego de saída (todas as portas e protocolos) para qualquer destino.
  - `tags`: Adiciona uma tag `Name` para identificação usando as [variáveis](#2-variáveis).

### 11. AMI (`data "aws_ami"`)

```terraform
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
```

- `data "aws_ami" "debian12`": Busca a AMI Debian 12 mais recente. É uma fonte de dados, não um recurso.
  - `most_recent` = true: Obtém a AMI mais recente.
  - `filter`: Filtra por nome (debian-12-amd64-*) e tipo de virtualização (hvm).
  - `owners`: Especifica o ID da conta AWS do proprietário da AMI (Debian).

### 12. Instância EC2 (`aws_instance`)

```terraform
resource "aws_instance" "debian_ec2" {
  ami             = data.aws_ami.debian12.id
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.main_subnet.id
  key_name        = aws_key_pair.ec2_key_pair.key_name
  security_groups = [aws_security_group.main_sg.name]

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
              EOF

  tags = {
    Name = "${var.projeto}-${var.candidato}-ec2"
  }
}
```

- `resource "aws_instance" "debian_ec2`": Cria a instância EC2.
  - `ami`: Usa a AMI obtida na fonte de dados data.aws_ami.debian12.id.
  - `instance_type` = "t2.micro": Define o tipo de instância (t2.micro é elegível para o nível gratuito).
  - `subnet_id`: Inicia a instância na sub-rede criada.
  - `key_name`: Associa o par de chaves SSH.
  - `security_groups`: Aplica o grupo de segurança.
  - `associate_public_ip_address` = true: Atribui um IP público à instância.
  - `root_block_device`: Configura o volume raiz:
    - `volume_size` = 20: Tamanho de 20 GiB.
    - `volume_type` = "gp2": Tipo de volume (General Purpose SSD).
    - `delete_on_termination` = true: Exclui o volume quando a instância for terminada.
  - `user_data`: Executa um script simples no momento da inicialização da instância (atualiza os pacotes). O <<-EOF é uma sintaxe "heredoc" para strings multilinhas.
  - `tags`: Adiciona uma tag `Name` para identificação usando as [variáveis](#2-variáveis).

### 13. Outputs

```terraform
output "private_key" {
  description = "Chave privada para acessar a instância EC2"
  value       = tls_private_key.ec2_key.private_key_pem
  sensitive   = true
}

output "ec2_public_ip" {
  description = "Endereço IP público da instância EC2"
  value       = aws_instance.debian_ec2.public_ip
}
```

- `output "private_ke`": Exibe a chave privada gerad`a (usada para se conectar à instância via SSH).
  - `value = tls_private_key.ec2_key.private_key_pem`: Obtém a chave privada do recurso tls_private_key.
  sensitive = true: Marca a saída como sensível, ocultando-a da saída padrão do Terraform (mas ainda estará no arquivo de estado). Importante para segurança!
- `output "ec2_public_i`": Exibe o endereço IP públic`o da instância EC2.
  - `value = aws_instance.debian_ec2.public_ip`: Obtém o IP público do recurso aws_instance.

## Alterações no Código Original

[Código Modificado](./modificado/main.tf)

Aqui estão as alterações que fiz no código de acordo com o que foi solicitado.

### Restrição de acesso SSH

```terraform
# Adicionado: variável para CIDR de Origem SSH
variable "ssh_cidr" {
  description = "CIDR permitido para acesso SSH."
  type = string
  default = "0.0.0.0/0"
}

#{...}

# MODIFICADO: Grupo de Segurança
resource "aws_security_group" "main_sg" {
  name        = "${var.projeto}-${var.candidato}-sg"
  vpc_id      = aws_vpc.main_vpc.id

  # Regras de entrada
  ingress {
    description = "Permitir SSH a partir de CIDR específico"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr] # Modificado: uso da variável ssh_cidr
  }

#{...}
```

- `variable "ssh_cidr"`: Cria uma variável para restringir a faixa de IP que pode acessar a instância EC2 por SSH.
- `default`: O valor padrão é o `0.0.0.0/0`, utilizado anteriormente.
- É possível definir o valor da variável por meio da linha de comando ao executar o `terraform apply`. Veja exemplo:

```bash
terraform apply -var="ssh_cidr=SEU_IP_PUBLICO/32"
```

Onde, `SEU_IP_PUBLICO/32` é o endereço IP Público que irá acessar a instância EC2 por SSH.

### Separação entre sub-rede pública e privada

Fiz a separação entre sub-rede pública e sub-rede privada. Isso permite a distinção entre recursos que podem ser expostos diretamente à Internet e os que não podem.

> NOTA:
>
>Mantive a instância EC2 na sub-rede pública, pois não sei como permitir o acesso por SSH estando na sub-rede privada. Acredito que estabelecer uma VPN seria uma opção ou uma instância EC2 na sub-rede pública que receba e direcione apenas o tráfego SSH para a EC2 na rede-privada.

#### Subnets (pública e privada)

```terraform
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
```

- `map_public_ip_on_launch`:
  - `true`: atribui IPs Públicos automaticamente.
  - `false`: não atribui IPs Públicos automaticamente.

```terraform
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
```

- Cada sub-rede tem sua tabela de rotas e associação da tabela com a sub-rede.
- `resource "aws_eip" "nat_eip"`: Cria um IP Elástico para o NAT Gateway.
- `resource "aws_nat_gateway" "nat_gateway"`: Cria o NAT Gateway, que irá conectar a sub-rede pública com a privada.

### HTTP e HTTPS

Modifiquei o security group para abrir as portas 80 e 443 para os protocolos HTTP e HTTPS, respectivamente.

```terraform
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
```

### Modificações no script `user_data` (`fail2ban`, `ufw` e `nginx`)

Adicionei as ferramentas fail2ban e ufw para maior segurança.

O `fail2ban` é uma ferramenta que ajuda a proteger contra ataques de força bruta SSH, banindo IPs que tentam repetidamente senhas incorretas.

O `ufw` um firewall simplificado para Debian/Ubuntu. Ele bloqueia todo o tráfego de entrada por padrão, exceto o que for explicitamente permitido (SSH, HTTP, HTTPS).

Também adicionei ao script o `nginx`, como solicitado.

```terraform
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
```

### Argumento `security_groups` em `aws_instance`

```terraform
resource "aws_instance" "debian_ec2_public" {
  ami             = data.aws_ami.debian12.id
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.public_subnet.id
  key_name        = aws_key_pair.ec2_key_pair.key_name
  vpc_security_group_ids = [aws_security_group.main_sg.id] #  Melhoria: Usar vpc_security_group_ids ao invés de security_groups
```

Troquei o argumento `security_groups` por `vpc_security_group_ids` como recomenda a [documentação](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance).
