variable "instance_type" {
  type        = string
  default     = "t2.micro"
  description = "The type of EC2 instance"
}

# DB 변수
variable "db_name" {
  type    = string
  default = "gitfit"
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type = string
}

# GitHub OAuth2
variable "github_client_id" {
  type = string
}

variable "github_client_secret" {
  type = string
}

# JWT
variable "jwt_secret" {
  type = string
}

# AI 서버 URL (백엔드에서 호출용)
variable "ai_server_url" {
  type    = string
  default = "https://ai.gitfit.site"
}

# AI EC2 SSH 키
variable "ai_ec2_key_name" {
  type        = string
  description = "gitfit-ai-kwy"
}