variable "domain_name"  { type = string }                # "gitfit.site"
variable "zone_id"      { type = string }                # Route53 Hosted Zone ID
variable "sans"         {
  type = list(string)
  default = ["www.gitfit.site"]
}
