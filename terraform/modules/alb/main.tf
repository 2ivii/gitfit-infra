# ALB Security Group (80, 443 오픈)
resource "aws_security_group" "alb" {
  # name 대신 name_prefix 사용
  name_prefix = "${var.name_prefix}-alb-"
  description = "Allow HTTP/HTTPS to ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress  {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true  # 새 SG 먼저 생성 → ALB에 붙인 뒤 → 옛 SG 삭제
  }
}


# ALB
resource "aws_lb" "this" {
  name               = "${var.name_prefix}-alb"
  load_balancer_type = "application"
  subnets            = var.subnets
  security_groups    = [aws_security_group.alb.id]
}

# Target Group (Fargate ip 타입)
resource "aws_lb_target_group" "tg" {
  # name        = "${var.name_prefix}-tg"  # 고정 이름 대신 prefix 사용
  name_prefix = var.tg_prefix              # ← 6자 이내 필수 (예: "gfit-")
  port        = var.target_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = var.hc_path
    matcher             = "200-399"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  lifecycle {
    create_before_destroy = true
  }
}

############################
# Listeners (HTTP/HTTPS)
############################

# HTTPS 사용 시: 80 → 443 리다이렉트
# 80 → 443 리다이렉트 (HTTPS 켜진 경우에만)
resource "aws_lb_listener" "http_redirect" {
  count             = var.enable_https ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# 443 리스너 (HTTPS)
resource "aws_lb_listener" "https" {
  count             = var.enable_https ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.certificate_arn

  lifecycle {
    precondition {
      condition     = var.certificate_arn != ""
      error_message = "enable_https=true 인 경우 certificate_arn을 반드시 넘겨야 합니다."
    }
  }

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# (HTTP only 모드일 때만 생성)
resource "aws_lb_listener" "http_only" {
  count             = var.enable_https ? 0 : 1
  load_balancer_arn = aws_lb.this.arn
  port              = var.listener_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

############################
# Outputs
############################

output "dns_name" {
  value = aws_lb.this.dns_name
}

output "security_group_id" {
  value = aws_security_group.alb.id
}

output "target_group_arn" {
  value = aws_lb_target_group.tg.arn
}

output "alb_arn" {
  value = aws_lb.this.arn
}

# Route53 ALIAS용
output "alb_zone_id" {
  value = aws_lb.this.zone_id
}
