variable "aws_region" {
  description = "Región AWS"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Profile de AWS CLI"
  type        = string
  default     = "admin"
}

variable "state_bucket_name" {
  description = "Nombre del bucket S3 para Terraform state (debe ser globalmente único)"
  type        = string
  default     = "homestack-tf-state"
}
