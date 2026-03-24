################################################################################
# RDS PostgreSQL - Dois bancos: prod (bia) e dev (bia-dev)
#
# bia     → db.t4g.micro (ARM) — ambiente de produção
# bia-dev → db.t3.micro        — ambiente de desenvolvimento
################################################################################

# RDS Produção
resource "aws_db_instance" "bia_prod" {
  identifier        = "bia"
  engine            = "postgres"
  engine_version    = "17.6"
  instance_class    = "db.t4g.micro"
  allocated_storage = 20
  storage_type      = "gp2"
  storage_encrypted = true

  db_name  = "bia"
  username = var.db_user
  password = var.db_prod_password

  vpc_security_group_ids = [aws_security_group.bia_db.id]
  publicly_accessible    = false
  skip_final_snapshot    = true  # para facilitar deleção em ambiente de treinamento
  backup_retention_period = 0   # sem backup automático (treinamento)
  multi_az               = false

  tags = { Name = "bia-prod" }
}

# RDS Desenvolvimento
resource "aws_db_instance" "bia_dev" {
  identifier        = "bia-dev"
  engine            = "postgres"
  engine_version    = "17.6"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_type      = "gp2"
  storage_encrypted = true

  db_name  = "bia"
  username = var.db_user
  password = var.db_dev_password

  vpc_security_group_ids = [aws_security_group.bia_dev.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
  backup_retention_period = 0
  multi_az               = false

  tags = { Name = "bia-dev" }
}
