# 보안그룹: ALB에서만 앱으로 인바운드 허용
resource "aws_security_group" "app" {
  name   = "${var.name_prefix}-app-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [var.alb_sg_id]   # ALB SG만 허용
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 로그 그룹
resource "aws_cloudwatch_log_group" "lg" {
  name              = "/ecs/${var.name_prefix}"
  retention_in_days = 7
}

# IAM: 태스크 실행/작업 역할
data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "exec" {
  name               = "${var.name_prefix}-ecs-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}
resource "aws_iam_role" "task" {
  name               = "${var.name_prefix}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

# 실행 역할에 필수 정책 부여(ECR pull, CW Logs 등)
resource "aws_iam_role_policy_attachment" "exec_logs" {
  role       = aws_iam_role.exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS 클러스터
resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-cluster"
}

# 태스크 정의
resource "aws_ecs_task_definition" "td" {
  family                   = "${var.name_prefix}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.exec.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name  = "app",
      image = var.container_image,
      portMappings = [{ containerPort = var.container_port, protocol = "tcp" }],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.lg.name,
          awslogs-region        = data.aws_region.current.name,
          awslogs-stream-prefix = "ecs"
        }
      },
      environment = [ for k, v in var.env_vars : { name = k, value = v } ]
    }
  ])
}

data "aws_region" "current" {}

# 서비스
resource "aws_ecs_service" "svc" {
  name            = "${var.name_prefix}-svc"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.td.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"
  enable_execute_command = var.enable_execute_command

  network_configuration {
    subnets         = var.subnets
    security_groups = [aws_security_group.app.id]
    assign_public_ip = false            # 프라이빗 서브넷 가정(실제 네트는 NAT 있음)
  }

  load_balancer {
    target_group_arn = var.alb_target_group_arn
    container_name   = "app"
    container_port   = var.container_port
  }
}

output "service_name" { value = aws_ecs_service.svc.name }
output "app_sg_id"    { value = aws_security_group.app.id }
