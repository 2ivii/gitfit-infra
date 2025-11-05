# 호스트존 조회
data "aws_route53_zone" "root" {
  name         = var.zone_name
  private_zone = false
}

# 1) 루트 도메인 → Vercel (A)
resource "aws_route53_record" "root_to_vercel" {
  zone_id         = data.aws_route53_zone.root.zone_id
  name            = var.zone_name                 # 예: gitfit.site
  type            = "A"
  ttl             = 60
  allow_overwrite = true
  records         = [var.vercel_root_ip]
}

# 2) www → Vercel (CNAME)
resource "aws_route53_record" "www_to_vercel" {
  zone_id         = data.aws_route53_zone.root.zone_id
  name            = "www.${var.zone_name}"       # 예: www.gitfit.site
  type            = "CNAME"
  ttl             = 60
  allow_overwrite = true
  records         = [var.vercel_www_cname]       # Vercel 프로젝트 화면의 정확값으로 교체 가능
}

# 3) api → 우리 ALB (A-ALIAS)
resource "aws_route53_record" "api_to_alb" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = "${var.api_subdomain}.${var.zone_name}"  # 예: api.gitfit.site
  type    = "A"

  alias {
    name                   = var.alb_dns_name   # 예: gitfit-dev-alb-....elb.amazonaws.com
    zone_id                = var.alb_zone_id    # ap-northeast-2 ALB Hosted Zone ID: ZWKZPGTI48KDX
    evaluate_target_health = true
  }

  allow_overwrite = true
}
