################################################################################
# ECS - Cluster, Auto Scaling Group, Task Definitions e Services
#
# Cluster: cluster-bia-alb
#   - 2 instâncias EC2 t3.micro (ECS-Optimized Amazon Linux 2023)
#   - Subnets: subnet-83abe6dc (us-east-1a) e subnet-9a90d0fc (us-east-1b)
#
# Services:
#   service-bia-alb     → task-def-bia-alb     → tg-bia     (prod)
#   service-bia-alb-dev → task-def-bia-alb-dev → tg-bia-dev (dev)
################################################################################

# ── Cluster ──────────────────────────────────────────────────────────────────

resource "aws_ecs_cluster" "bia_alb" {
  name = "cluster-bia-alb"
}

# ── Launch Template para as EC2 do cluster ───────────────────────────────────

resource "aws_launch_template" "bia_ecs" {
  name_prefix   = "bia-ecs-"
  image_id      = var.ecs_ami_id
  instance_type = "t3.micro"

  # Registra a instância no cluster ECS ao iniciar
  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.bia_alb.name} >> /etc/ecs/ecs.config
  EOF
  )

  iam_instance_profile {
    arn = var.ecs_instance_profile_arn
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.bia_ec2.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "ECS Instance - cluster-bia-alb", AmazonECSManaged = "" }
  }
}

# ── Auto Scaling Group (2 instâncias fixas) ───────────────────────────────────

resource "aws_autoscaling_group" "bia_ecs" {
  name                = "bia-ecs-asg"
  desired_capacity    = 2
  min_size            = 1
  max_size            = 2
  vpc_zone_identifier = var.subnet_ids

  launch_template {
    id      = aws_launch_template.bia_ecs.id
    version = "$Latest"
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = ""
    propagate_at_launch = true
  }
}

# ── Capacity Provider ligando o ASG ao cluster ────────────────────────────────

resource "aws_ecs_capacity_provider" "bia_asg" {
  name = "bia-asg-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.bia_ecs.arn

    managed_scaling {
      status          = "ENABLED"
      target_capacity = 100
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "bia_alb" {
  cluster_name       = aws_ecs_cluster.bia_alb.name
  capacity_providers = [aws_ecs_capacity_provider.bia_asg.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.bia_asg.name
    weight            = 1
    base              = 0
  }
}

# ── Task Definition - Produção ────────────────────────────────────────────────
# Imagem: bia:4e8d385 | CPU: 1024 | Mem: 410 MB | Porta: 8080 (bridge/dinâmica)

resource "aws_ecs_task_definition" "bia_alb_prod" {
  family                   = "task-def-bia-alb"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = var.ecs_task_execution_role_arn

  container_definitions = jsonencode([{
    name              = "bia"
    image             = var.ecr_image_prod
    cpu               = 1024
    memoryReservation = 410
    essential         = true

    portMappings = [{
      containerPort = 8080
      hostPort      = 0       # porta dinâmica (bridge mode)
      protocol      = "tcp"
      name          = "porta-aleatorio"
      appProtocol   = "http"
    }]

    environment = [
      { name = "DB_HOST", value = var.db_prod_host },
      { name = "DB_PORT", value = var.db_port },
      { name = "DB_USER", value = var.db_user },
      { name = "DB_PWD",  value = var.db_prod_password }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/task-def-bia"
        "awslogs-create-group"  = "true"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

# ── Task Definition - Desenvolvimento ────────────────────────────────────────
# Imagem: bia:b80216a | CPU: 1024 | Mem: 410 MB | Porta: 8080 (bridge/dinâmica)

resource "aws_ecs_task_definition" "bia_alb_dev" {
  family                   = "task-def-bia-alb-dev"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = var.ecs_task_execution_role_arn

  container_definitions = jsonencode([{
    name              = "bia"
    image             = var.ecr_image_dev
    cpu               = 1024
    memoryReservation = 410
    essential         = true

    portMappings = [{
      containerPort = 8080
      hostPort      = 0
      protocol      = "tcp"
      name          = "porta-aleatorio"
      appProtocol   = "http"
    }]

    environment = [
      { name = "DB_HOST", value = var.db_dev_host },
      { name = "DB_PORT", value = var.db_port },
      { name = "DB_USER", value = var.db_user },
      { name = "DB_PWD",  value = var.db_dev_password }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/task-def-bia"
        "awslogs-create-group"  = "true"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

# ── ECS Service - Produção ────────────────────────────────────────────────────
# 2 tasks | rolling update | spread por AZ e instanceId

resource "aws_ecs_service" "bia_alb_prod" {
  name            = "service-bia-alb"
  cluster         = aws_ecs_cluster.bia_alb.id
  task_definition = aws_ecs_task_definition.bia_alb_prod.arn
  desired_count   = 2
  launch_type     = "EC2"

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 100

  load_balancer {
    target_group_arn = aws_lb_target_group.tg_bia.arn
    container_name   = "bia"
    container_port   = 8080
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "instanceId"
  }

  depends_on = [aws_lb_listener.http, aws_lb_listener.https]
}

# ── ECS Service - Desenvolvimento ────────────────────────────────────────────
# 2 tasks | rolling update | spread por AZ e instanceId

resource "aws_ecs_service" "bia_alb_dev" {
  name            = "service-bia-alb-dev"
  cluster         = aws_ecs_cluster.bia_alb.id
  task_definition = aws_ecs_task_definition.bia_alb_dev.arn
  desired_count   = 2
  launch_type     = "EC2"

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 100

  load_balancer {
    target_group_arn = aws_lb_target_group.tg_bia_dev.arn
    container_name   = "bia"
    container_port   = 8080
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "instanceId"
  }

  depends_on = [aws_lb_listener.https]
}
