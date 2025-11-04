# 루트 도메인 A 레코드 (ALB로 Alias)
resource "aws_route53_record" "root" {
  zone_id = var.zone_id
  name    = var.root_name
  type    = "A"
  allow_overwrite = true

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# www CNAME → root (선택)
resource "aws_route53_record" "www" {
  count   = var.create_www ? 1 : 0
  zone_id = var.zone_id
  name    = "www.${var.root_name}"
  type    = "CNAME"
  ttl     = 300
  records = [var.root_name]
  allow_overwrite = true
}