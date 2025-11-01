variable "name_prefix" { type = string }
variable "cidr_block" { type = string }
variable "public_subnets" { type = list(string) }
variable "private_subnets" { type = list(string) }
variable "create_nat" { type = bool }
