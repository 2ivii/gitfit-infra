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