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
  target_port = 8080         # 나중에 ECS 컨테이너 포트와 일치시킬 것
}

output "message"            { value = "Terraform is connected to AWS successfully!" }
output "vpc_id"             { value = module.network.vpc_id }
output "public_subnet_ids"  { value = module.network.public_subnet_ids }
output "private_subnet_ids" { value = module.network.private_subnet_ids }
output "alb_dns_name" { value = module.alb.dns_name }
