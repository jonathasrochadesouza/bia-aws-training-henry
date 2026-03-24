################################################################################
# Security Groups - Projeto BIA
#
# Topologia:
#   Internet → bia-alb (80/443) → bia-ec2 (all TCP) → bia-db (5432)
#   bia-dev (EC2 de trabalho) → bia-db (5432)
#   bia-web (cenário sem ALB) → bia-db (5432)
################################################################################

# bia-alb: recebe tráfego público HTTP/HTTPS
resource "aws_security_group" "bia_alb" {
  name        = "bia-alb"
  description = "bia-alb access"
  vpc_id      = var.vpc_id

  # HTTP público
  ingress {
    description = "Free all access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS público
  ingress {
    description = "Free all access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "Bia ALB", project = "bia" }
}

# bia-ec2: instâncias EC2 do cluster ECS — aceita todo TCP vindo do ALB
# (portas dinâmicas do ECS bridge mode)
resource "aws_security_group" "bia_ec2" {
  name        = "bia-ec2"
  description = "bia-ec2 access"
  vpc_id      = var.vpc_id

  ingress {
    description     = "access by bia-alb"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.bia_alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "bia EC2" }
}

# bia-db: RDS PostgreSQL — aceita conexões de bia-ec2, bia-dev e bia-web
resource "aws_security_group" "bia_db" {
  name        = "bia-db"
  description = "bia-db access"
  vpc_id      = var.vpc_id

  ingress {
    description     = "access by bia-ec2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.bia_ec2.id]
  }

  ingress {
    description     = "access by bia-dev EC2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.bia_dev.id]
  }

  ingress {
    description     = "access by bia-web"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.bia_web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "Bia DB" }
}

# bia-web: cenário sem ALB — expõe porta 80 diretamente
resource "aws_security_group" "bia_web" {
  name        = "bia-web"
  description = "bia-web access"
  vpc_id      = var.vpc_id

  ingress {
    description = "All access free"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All access free"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "Bia WEB" }
}

# bia-dev: EC2 de trabalho/desenvolvimento — expõe porta 3001
resource "aws_security_group" "bia_dev" {
  name        = "bia-dev"
  description = "bia-dev access"
  vpc_id      = var.vpc_id

  ingress {
    description = "Access granted"
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "Bia DEV", project = "bia" }
}
