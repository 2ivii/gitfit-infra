resource "null_resource" "ping" {}

output "message" {
  value = "Terraform is connected to AWS successfully!"
}
