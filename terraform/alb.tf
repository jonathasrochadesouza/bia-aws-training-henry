################################################################################
# ALB - Application Load Balancer
#
# bia-alb (internet-facing)
#   Listener HTTP  :80  → forward para tg-bia (prod) por padrão
#   Listener HTTPS :443 → regra host-header formacao-dev.bia-aws.com.br → tg-bia-dev
#                       → default: tg-bia (prod)
#
# Target Groups:
#   tg-bia     → service-bia-alb     (produção)   → formacaojkrocha.com.br
#   tg-bia-dev → service-bia-alb-dev (dev)         → formacao-dev.jkrocha.com.br
################################################################################

resource "aws_lb" "bia_alb" {
  name               = "bia-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.bia_alb.id]
  subnets            = var.subnet_ids
}

# Target Group - Produção
resource "aws_lb_target_group" "tg_bia" {
  name        = "tg-bia"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

# Target Group - Desenvolvimento
resource "aws_lb_target_group" "tg_bia_dev" {
  name        = "tg-bia-dev"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

# Listener HTTP :80 → forward para tg-bia (prod)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.bia_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_bia.arn
  }
}

# Listener HTTPS :443 → default para tg-bia (prod)
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.bia_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_bia.arn
  }
}

# Listener Rule HTTPS: host-header formacao-dev.bia-aws.com.br → tg-bia-dev
resource "aws_lb_listener_rule" "dev_host_header" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 1

  condition {
    host_header {
      values = ["formacao-dev.bia-aws.com.br"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_bia_dev.arn
  }
}
