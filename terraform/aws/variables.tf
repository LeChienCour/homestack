variable "aws_region" {
  description = "Región AWS para SES. us-east-1 es la más usada por su política de envío."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Profile de AWS CLI configurado en ~/.aws/credentials"
  type        = string
  default     = "homestack"
}

variable "domain" {
  description = "Dominio principal (ej. tudominio.com). Será verificado en SES."
  type        = string
}

variable "from_email_local_part" {
  description = "Parte local del email para Listmonk (ej. 'noreply' → noreply@tudominio.com)"
  type        = string
  default     = "noreply"
}
