variable "zone_id"      { type = string }          # Hosted Zone ID
variable "root_name"    { type = string }          # "gitfit.site"
variable "alb_dns_name" { type = string }
variable "alb_zone_id"  { type = string }
variable "create_www"   {
  type = bool
  default = true
}
