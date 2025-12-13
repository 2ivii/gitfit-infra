variable "bucket_name" {
  type        = string
  description = "gitfit-bucket"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply"
  default     = {}
}

variable "versioning" {
  type        = bool
  description = "Enable versioning"
  default     = false
}

variable "force_destroy" {
  type        = bool
  description = "Allow terraform to destroy bucket even if it contains objects"
  default     = false
}

variable "block_public_access" {
  type        = bool
  description = "Block all public access"
  default     = true
}

variable "lifecycle_abort_multipart_days" {
  type        = number
  description = "Abort incomplete multipart uploads after N days"
  default     = 7
}
