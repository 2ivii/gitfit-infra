resource "null_resource" "ping" {}
# gitfit.site 도메인에 Amazon(ACM) 발급 허용
resource "aws_route53_record" "caa_amazon" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = "gitfit.site"
  type    = "CAA"
  ttl     = 300
  records = [
    "0 issue \"amazon.com\"",
    "0 issuewild \"amazon.com\""
  ]
  allow_overwrite = true
}



module "network" {
  source          = "../../modules/network"
  name_prefix     = "gitfit-dev"
  cidr_block      = "10.0.0.0/16"
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.11.0/24", "10.0.12.0/24"]
  create_nat      = true
}

# module "alb" {
#   source      = "../../modules/alb"
#   name_prefix = "gitfit-dev"
#   vpc_id      = module.network.vpc_id
#   subnets     = module.network.public_subnet_ids
#   hc_path     = "/"
#   target_port = 80        # nginx 기본 포트
# }

module "ecs" {
  source               = "../../modules/ecs_service"
  name_prefix          = "gitfit-dev"
  vpc_id               = module.network.vpc_id
  subnets              = module.network.private_subnet_ids
  container_image      = "${module.ecr.repository_url}:latest"
  container_port       = 80
  desired_count        = 1
  cpu                  = 256
  memory               = 512
  alb_target_group_arn = module.alb.target_group_arn
  alb_sg_id            = module.alb.security_group_id
  env_vars             = { SPRING_PROFILES_ACTIVE = "dev" }
}

module "ecr" {
  source      = "../../modules/ecr"
  name_prefix = "gitfit-dev"
}

# 4-1) Hosted Zone 조회 (Route53에 이미 존재한다고 가정)
data "aws_route53_zone" "root" {
  name         = "gitfit.site."
  private_zone = false
}

# 4-2) ACM 인증서 발급 + DNS 검증
module "acm" {
  source      = "../../modules/acm"
  domain_name = "gitfit.site"
  zone_id     = data.aws_route53_zone.root.zone_id
  sans        = ["www.gitfit.site"]
}

# 4-3) ALB에 HTTPS 연결(443 리스너 생성 + 80→443 리다이렉트)
module "alb" {
  source          = "../../modules/alb"
  name_prefix     = "gitfit-dev"
  vpc_id          = module.network.vpc_id
  subnets         = module.network.public_subnet_ids
  hc_path         = "/"
  target_port     = 80
  tg_prefix       = "gfit-"                   # 6자 이내
  enable_https    = true
  certificate_arn = module.acm.certificate_arn
}

# 4-4) Route53 A 레코드 → ALB ALIAS
module "dns" {
  source       = "../../modules/dns"
  zone_id      = data.aws_route53_zone.root.zone_id
  root_name    = "gitfit.site"
  alb_dns_name = module.alb.dns_name
  alb_zone_id  = module.alb.alb_zone_id
  create_www   = true
}




output "message"            { value = "Terraform is connected to AWS successfully!" }
output "vpc_id"             { value = module.network.vpc_id }
output "public_subnet_ids"  { value = module.network.public_subnet_ids }
output "private_subnet_ids" { value = module.network.private_subnet_ids }
output "alb_dns_name" { value = module.alb.dns_name }
output "service_name" { value = module.ecs.service_name }

