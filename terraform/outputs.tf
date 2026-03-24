################################################################################
# Outputs - valores úteis após o terraform apply
################################################################################

output "alb_dns_name" {
  description = "DNS do Application Load Balancer"
  value       = aws_lb.bia_alb.dns_name
}

output "ecr_repository_uri" {
  description = "URI do repositório ECR para push de imagens"
  value       = aws_ecr_repository.bia.repository_url
}

output "rds_prod_endpoint" {
  description = "Endpoint do RDS de produção"
  value       = aws_db_instance.bia_prod.address
}

output "rds_dev_endpoint" {
  description = "Endpoint do RDS de desenvolvimento"
  value       = aws_db_instance.bia_dev.address
}

output "ecs_cluster_name" {
  description = "Nome do cluster ECS"
  value       = aws_ecs_cluster.bia_alb.name
}
