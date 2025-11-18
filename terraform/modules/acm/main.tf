# ACM 인증서 모듈
# - domain_name: gitfit.site (또는 api.gitfit.site 등)
# - sans: 추가로 인증서에 넣고 싶은 도메인 목록
#
# 주의: www.gitfit.site 는 Vercel에서 관리하면서
#       CAA 레코드로 Amazon(ACM)을 막고 있으므로,
#       SAN에서 자동으로 제외하도록 필터링한다.

locals {
  # SAN 목록에서 www.gitfit.site 는 제외
  # (없으면 그냥 빈 리스트 또는 원본 유지)
  filtered_sans = var.sans == null ? [] : [
    for s in var.sans : s
    if s != "www.gitfit.site"
  ]
}

# 인증서는 ALB와 같은 리전에 있어야 함 (ap-northeast-2)
resource "aws_acm_certificate" "this" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  # www.gitfit.site 는 위의 local.filtered_sans 에서 이미 제거됨
  subject_alternative_names = local.filtered_sans

  # 중요: ALB가 사용 중일 때 인증서 교체를 위해 필요
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.domain_name}-certificate"
  }
}

# DNS 검증 레코드 생성
resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id         = var.zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.record]
  allow_overwrite = true  # 기존 검증 레코드가 있을 경우 덮어쓰기 허용
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for r in aws_route53_record.validation : r.fqdn]
}

output "certificate_arn" {
  value = aws_acm_certificate_validation.this.certificate_arn
}