resource "null_resource" "ping" {}

module "network" {
  source          = "../../modules/network"
  name_prefix     = "gitfit-dev"
  cidr_block      = "10.0.0.0/16"
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.11.0/24", "10.0.12.0/24"]
  create_nat      = true
}

module "alb" {
  source      = "../../modules/alb"
  name_prefix = "gitfit-dev"
  vpc_id      = module.network.vpc_id
  subnets     = module.network.public_subnet_ids
  hc_path     = "/"
  target_port = 80        # nginx 기본 포트
}

module "ecs" {
  source               = "../../modules/ecs_service"
  name_prefix          = "gitfit-dev"
  vpc_id               = module.network.vpc_id
  subnets              = module.network.private_subnet_ids
  container_image      = "nginx:alpine"
  container_port       = 80
  desired_count        = 1
  cpu                  = 256
  memory               = 512
  alb_target_group_arn = module.alb.target_group_arn
  alb_sg_id            = module.alb.security_group_id
  env_vars             = { SPRING_PROFILES_ACTIVE = "dev" }
}


output "message"            { value = "Terraform is connected to AWS successfully!" }
output "vpc_id"             { value = module.network.vpc_id }
output "public_subnet_ids"  { value = module.network.public_subnet_ids }
output "private_subnet_ids" { value = module.network.private_subnet_ids }
output "alb_dns_name" { value = module.alb.dns_name }
output "service_name" { value = module.ecs.service_name }

