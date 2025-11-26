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
  type = string
}

variable "target_port" {
  type = number
}

variable "tg_prefix" {
  type = string
}

variable "enable_https" {
  type    = bool
  default = true
}

variable "certificate_arn" {
  type = string
}