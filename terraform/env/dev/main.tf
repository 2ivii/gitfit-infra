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

############################
# 네트워크 (VPC + Subnets)
############################
module "network" {
  source          = "../../modules/network"
  name_prefix     = "gitfit-dev"
  cidr_block      = "10.0.0.0/16"
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.11.0/24", "10.0.12.0/24"]
  create_nat      = true
}

############################
# ECS (여기에 env_vars로 DB/GitHub/JWT 전달)
############################
module "ecs" {
  source               = "../../modules/ecs_service"
  name_prefix          = "gitfit-dev"
  vpc_id               = module.network.vpc_id
  subnets              = module.network.private_subnet_ids
  container_image      = "935194211812.dkr.ecr.ap-northeast-2.amazonaws.com/gitfit-dev-repo:latest"
  container_port       = 80
  desired_count        = 1
  cpu                  = 256
  memory               = 512
  alb_target_group_arn = module.alb.target_group_arn
  alb_sg_id            = module.alb.security_group_id

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

    # AI 서버
    AI_SERVER_URL = var.ai_server_url
  }
}

############################
# ECR
############################
module "ecr" {
  source      = "../../modules/ecr"
  name_prefix = "gitfit-dev"
}

############################
# Route53 Hosted Zone 조회
############################
data "aws_route53_zone" "root" {
  name         = "gitfit.site."
  private_zone = false
}

############################
# ACM
############################
module "acm" {
  source      = "../../modules/acm"
  domain_name = "gitfit.site"
  zone_id     = data.aws_route53_zone.root.zone_id
  sans        = [
    "www.gitfit.site",
    "api.gitfit.site"
  ]
}

############################
# ALB (HTTPS)
############################
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

############################
# DNS → ALB
############################
module "dns" {
  source        = "../../modules/dns"
  zone_name     = "gitfit.site"
  alb_dns_name  = module.alb.dns_name
  alb_zone_id   = "ZWKZPGTI48KDX" # 서울 리전 ALB Zone ID
  api_subdomain = "api"
}

############################
# RDS: Subnet Group
############################
resource "aws_db_subnet_group" "db" {
  name       = "gitfit-dev-db-subnet-group"

  subnet_ids = module.network.public_subnet_ids

  tags = {
    Name = "gitfit-dev-db-subnet-group"
  }
}

############################
# RDS: Security Group
############################
resource "aws_security_group" "db" {
  name   = "gitfit-dev-db-sg"
  vpc_id = module.network.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"

    # 여기는 나중에 더 구체적으로 제한해도 됨 (현재 dev용)
    cidr_blocks = ["10.0.0.0/16"]
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

############################
# RDS: MySQL Instance
############################
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

############################
# 출력값
############################
output "message"            { value = "Terraform connected!" }
output "vpc_id"             { value = module.network.vpc_id }
output "public_subnet_ids"  { value = module.network.public_subnet_ids }
output "private_subnet_ids" { value = module.network.private_subnet_ids }
output "alb_dns_name"       { value = module.alb.dns_name }
output "service_name"       { value = module.ecs.service_name }
output "db_endpoint"        { value = aws_db_instance.db.address }
output "db_port"            { value = aws_db_instance.db.port }