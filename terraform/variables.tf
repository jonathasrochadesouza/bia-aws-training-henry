################################################################################
# Variáveis - ajuste antes de aplicar
################################################################################

variable "aws_region" {
  description = "Região AWS"
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC padrão do projeto"
  default     = "vpc-4cec7031"
}

# Subnets usadas pelo cluster ECS e ALB (us-east-1a e us-east-1b)
variable "subnet_ids" {
  description = "Subnets para o cluster ECS e ALB"
  type        = list(string)
  default     = ["subnet-83abe6dc", "subnet-9a90d0fc"]
}

variable "ecr_image_prod" {
  description = "Imagem ECR para o ambiente de produção (tag do último deploy)"
  default     = "328958872848.dkr.ecr.us-east-1.amazonaws.com/bia:4e8d385"
}

variable "ecr_image_dev" {
  description = "Imagem ECR para o ambiente de desenvolvimento"
  default     = "328958872848.dkr.ecr.us-east-1.amazonaws.com/bia:b80216a"
}

# Credenciais do banco — substitua por Secrets Manager em produção real
variable "db_prod_host" {
  description = "Endpoint do RDS de produção"
  default     = "bia.ctia5vvkqkpn.us-east-1.rds.amazonaws.com"
}

variable "db_prod_password" {
  description = "Senha do RDS de produção"
  sensitive   = true
  default     = "btm7o8oteQuaJSqUJiRv"
}

variable "db_dev_host" {
  description = "Endpoint do RDS de desenvolvimento"
  default     = "bia-dev.ctia5vvkqkpn.us-east-1.rds.amazonaws.com"
}

variable "db_dev_password" {
  description = "Senha do RDS de desenvolvimento"
  sensitive   = true
  default     = "vZyrezY308XmC9c4basw"
}

variable "db_user" {
  description = "Usuário do banco de dados"
  default     = "postgres"
}

variable "db_port" {
  description = "Porta do PostgreSQL"
  default     = "5432"
}

# IAM — role já existente na conta para execução das tasks ECS
variable "ecs_task_execution_role_arn" {
  description = "ARN da role de execução das tasks ECS"
  default     = "arn:aws:iam::328958872848:role/ecsTaskExecutionRole"
}

# IAM — instance profile para as EC2 do cluster ECS
variable "ecs_instance_profile_arn" {
  description = "ARN do instance profile das EC2 do cluster ECS"
  default     = "arn:aws:iam::328958872848:instance-profile/ecsInstanceRole"
}

# AMI ECS-Optimized Amazon Linux 2023 (us-east-1) — atualize se necessário
variable "ecs_ami_id" {
  description = "AMI ECS-Optimized para as instâncias do cluster"
  default     = "ami-00a99f084d9fa1629"
}

# Certificado ACM para o listener HTTPS
variable "acm_certificate_arn" {
  description = "ARN do certificado ACM para HTTPS no ALB"
  default     = "arn:aws:acm:us-east-1:328958872848:certificate/1100cacc-4d47-43df-a42f-a9fd36a9f3ae"
}
