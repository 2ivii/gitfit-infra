variable "zone_name" {
  type = string
}

variable "alb_dns_name" {
  type = string
}

variable "alb_zone_id" {
  type = string
}

variable "api_subdomain" {
  type    = string
  default = "api"
}

# Vercel 쪽 값 — 필요시 프로젝트에서 제시하는 값으로 바꾸세요.
variable "vercel_root_ip" {
  type    = string
  default = "76.76.21.21"
}

variable "vercel_www_cname" {
  type    = string
  default = "cname.vercel-dns.com"
}
