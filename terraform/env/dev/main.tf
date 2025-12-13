resource "null_resource" "ping" {}

############################
# gitfit.site 도메인 ACM 발급 허용
############################
resource "aws_route53_record" "caa_amazon" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = "gitfit.site"
  type    = "CAA"
  ttl     = 300

  records = [
    "0 issue \"amazon.com\"",
    "0 issuewild \"amazon.com\"",
    "0 issue \"amazontrust.com\"",
    "0 issuewild \"amazontrust.com\"",
    "0 issue \"awstrust.com\"",
    "0 issuewild \"awstrust.com\""
  ]

  allow_overwrite = true
}

########################################
# 네트워크 (VPC + Subnets)
########################################
module "network" {
  source          = "../../modules/network"
  name_prefix     = "gitfit-dev"
  cidr_block      = "10.0.0.0/16"
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.11.0/24", "10.0.12.0/24"]

  # 🔥 NAT 비활성화 → NAT Gateway / EIP 생성 안 됨 → 과금 차단
  create_nat      = false
}

########################################
# ECS (백엔드 - Fargate)
########################################
module "ecs" {
  source               = "../../modules/ecs_service"
  name_prefix          = "gitfit-dev"
  vpc_id               = module.network.vpc_id

  # 🔥 퍼블릭 서브넷으로 변경 (기존: module.network.private_subnet_ids)
  #    + ecs_service 모듈 내부에서 assign_public_ip = true
  subnets              = module.network.public_subnet_ids

  container_image      = "935194211812.dkr.ecr.ap-northeast-2.amazonaws.com/gitfit-dev-repo:latest"
  container_port       = 80
  desired_count        = 1
  cpu                  = 256
  memory               = 512
  alb_target_group_arn = module.alb.target_group_arn
  alb_sg_id            = module.alb.security_group_id
  task_policy_json = data.aws_iam_policy_document.ecs_s3_assets.json


  env_vars = {
    SPRING_PROFILES_ACTIVE = "dev"

    # RDS
    DB_HOST     = aws_db_instance.db.address
    DB_PORT     = tostring(aws_db_instance.db.port)
    DB_NAME     = var.db_name
    DB_USERNAME = var.db_username
    DB_PASSWORD = var.db_password

    # GitHub OAuth2
    GITHUB_CLIENT_ID     = var.github_client_id
    GITHUB_CLIENT_SECRET = var.github_client_secret

    # JWT
    JWT_SECRET = var.jwt_secret

    # AI 서버 (도메인으로 호출)
    AI_SERVER_URL = var.ai_server_url
  }
}

########################################
# ECR
########################################
module "ecr" {
  source      = "../../modules/ecr"
  name_prefix = "gitfit-dev"
}

########################################
# Route53 Hosted Zone 조회
########################################
data "aws_route53_zone" "root" {
  name         = "gitfit.site."
  private_zone = false
}

########################################
# ACM (gitfit.site + 서브도메인 인증서)
########################################
module "acm" {
  source      = "../../modules/acm"
  domain_name = "gitfit.site"
  zone_id     = data.aws_route53_zone.root.zone_id

  sans = [
    "www.gitfit.site",
    "api.gitfit.site",
    "ai.gitfit.site"   # ✅ AI 서브도메인 추가
  ]
}

########################################
# ALB (HTTPS)
########################################
module "alb" {
  source          = "../../modules/alb"
  name_prefix     = "gitfit-dev"
  vpc_id          = module.network.vpc_id
  subnets         = module.network.public_subnet_ids
  hc_path         = "/"
  target_port     = 80
  tg_prefix       = "gfit-"
  enable_https    = true
  certificate_arn = module.acm.certificate_arn
}

########################################
# ✅ AI 서버용 EC2 + Target Group + Listener Rule
########################################

# AI EC2용 보안 그룹 (ALB에서만 8000 포트 허용)
resource "aws_security_group" "ai" {
  name   = "gitfit-dev-ai-sg"
  vpc_id = module.network.vpc_id

  # ALB에서의 8000 포트 트래픽만 허용 (현재는 VPC 전체 허용)
  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]   # dev용
    # security_groups = [module.alb.security_group_id]
  }

  # (필요 시 SSH 열고 싶으면 아래처럼 추가)
  # ingress {
  #   from_port   = 22
  #   to_port     = 22
  #   protocol    = "tcp"
  #   cidr_blocks = ["너_IP/32"]
  # }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "gitfit-dev-ai-sg"
  }
}

# AI EC2 인스턴스
resource "aws_instance" "ai" {
  ami                    = "ami-0c9c942bd7bf113a2" # 예시: Amazon Linux 2023 (서울 리전)
  instance_type          = "t3.micro"
  subnet_id              = module.network.public_subnet_ids[0] # 퍼블릭 서브넷 하나 사용
  vpc_security_group_ids = [aws_security_group.ai.id]
  key_name               = var.ai_ec2_key_name  # SSH용 키페어

  user_data = <<EOF
#!/bin/bash
dnf update -y
dnf install -y docker
systemctl enable docker
systemctl start docker

# 여기에 AI 서버 이미지/실행 스크립트 넣기
# aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin 935194211812.dkr.ecr.ap-northeast-2.amazonaws.com
# docker run -d -p 8000:8000 935194211812.dkr.ecr.ap-northeast-2.amazonaws.com/gitfit-ai-repo:latest
EOF

  tags = {
    Name = "gitfit-dev-ai"
  }
}

# ALB의 AI용 Target Group (EC2 타겟)
resource "aws_lb_target_group" "ai" {
  name        = "gitfit-dev-ai-tg"
  port        = 8000
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = module.network.vpc_id

  health_check {
    path                = "/health"   # AI 서버 헬스 체크 엔드포인트에 맞게 변경
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }
}

# EC2를 AI Target Group에 등록
resource "aws_lb_target_group_attachment" "ai" {
  target_group_arn = aws_lb_target_group.ai.arn
  target_id        = aws_instance.ai.id
  port             = 8000
}

# HTTPS 리스너에 ai.gitfit.site 호스트 기반 라우팅 룰 추가
resource "aws_lb_listener_rule" "ai" {
  listener_arn = module.alb.https_listener_arn

  condition {
    host_header {
      values = ["ai.gitfit.site"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ai.arn
  }

  priority = 10  # 다른 룰들과 겹치지 않게 우선순위 설정
}

########################################
# DNS → ALB (api.gitfit.site, 등)
########################################
module "dns" {
  source        = "../../modules/dns"
  zone_name     = "gitfit.site"
  alb_dns_name  = module.alb.dns_name
  alb_zone_id   = "ZWKZPGTI48KDX" # 서울 리전 ALB Zone ID
  api_subdomain = "api"
}

# ai.gitfit.site → ALB (AI용)
resource "aws_route53_record" "ai" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = "ai.gitfit.site"
  type    = "A"

  alias {
    name                   = module.alb.dns_name
    zone_id                = "ZWKZPGTI48KDX" # 서울 리전 ALB Zone ID
    evaluate_target_health = true
  }
}

########################################
# RDS: Subnet Group
########################################
resource "aws_db_subnet_group" "db" {
  name       = "gitfit-dev-db-subnet-group"
  subnet_ids = module.network.public_subnet_ids

  tags = {
    Name = "gitfit-dev-db-subnet-group"
  }
}

########################################
# RDS: Security Group
########################################
resource "aws_security_group" "db" {
  name   = "gitfit-dev-db-sg"
  vpc_id = module.network.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # VPC 전체에서 허용 (dev용)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "gitfit-dev-db-sg"
  }
}

########################################
# RDS: MySQL Instance
########################################
resource "aws_db_instance" "db" {
  identifier            = "gitfit-dev-db"
  allocated_storage     = 20
  max_allocated_storage = 100

  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 3306

  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.db.id]

  publicly_accessible = false
  skip_final_snapshot = true
  storage_type        = "gp3"

  apply_immediately = true

  tags = {
    Name = "gitfit-dev-db"
  }
}

########################################
# S3 (Assets Bucket)
########################################
module "s3_assets" {
  source = "../../modules/s3"

  bucket_name         = "gitfit-dev-assets"
  versioning          = true
  force_destroy       = false
  block_public_access = true

  tags = {
    Name    = "gitfit-dev-assets"
    Project = "gitfit"
    Env     = "dev"
  }
}

########################################
# S3 CORS (for browser upload/download)
########################################
resource "aws_s3_bucket_cors_configuration" "assets" {
  bucket = module.s3_assets.bucket_name

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = [
      "https://gitfit.site",
      "https://www.gitfit.site",
      "https://api.gitfit.site",
      "https://ai.gitfit.site"
    ]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

data "aws_iam_policy_document" "ecs_s3_assets" {
  statement {
    sid     = "ListBucket"
    actions = ["s3:ListBucket"]
    resources = [module.s3_assets.bucket_arn]
  }

  statement {
    sid = "ObjectRW"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = ["${module.s3_assets.bucket_arn}/*"]
  }
}



########################################
# 출력값
########################################
output "message"            { value = "Terraform connected!" }
output "vpc_id"             { value = module.network.vpc_id }
output "public_subnet_ids"  { value = module.network.public_subnet_ids }
output "private_subnet_ids" { value = module.network.private_subnet_ids }
output "alb_dns_name"       { value = module.alb.dns_name }
output "service_name"       { value = module.ecs.service_name }
output "db_endpoint"        { value = aws_db_instance.db.address }
output "db_port"            { value = aws_db_instance.db.port }
