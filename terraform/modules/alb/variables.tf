variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnets" {
  type = list(string)
}

variable "hc_path" {
  type    = string
  default = "/"
}

variable "listener_port" {
  type    = number
  default = 80
}

variable "target_port" {
  type    = number
  default = 8080
}

variable "tg_prefix" {
  type    = string
  default = "gfit-"
}

# HTTPS 옵션
variable "enable_https" {
  type    = bool
  default = true
}

variable "certificate_arn" {
  type    = string
  default = ""           # ACM ARN 주입되면 443 리스너 생성
}