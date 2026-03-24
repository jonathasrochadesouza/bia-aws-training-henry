################################################################################
# BIA - Infraestrutura AWS
# Snapshot: 2026-03-24
#
# Recursos cobertos:
#   - ECR Repository
#   - Security Groups (bia-alb, bia-ec2, bia-db, bia-web, bia-dev)
#   - Application Load Balancer + Listeners + Listener Rules
#   - Target Groups (tg-bia, tg-bia-dev)
#   - ECS Cluster (cluster-bia-alb) via Auto Scaling Group
#   - ECS Task Definitions (prod + dev)
#   - ECS Services (service-bia-alb + service-bia-alb-dev)
#   - RDS PostgreSQL (bia + bia-dev)
#
# Para recriar: terraform init && terraform apply
################################################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
