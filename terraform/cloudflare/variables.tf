variable "cloudflare_api_token" {
  description = "API token con permisos Zone:DNS:Edit y Account:Cloudflare Tunnel:Edit"
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Account ID (visible en URL del dashboard de Cloudflare)"
  type        = string
  sensitive   = true
}

variable "domain" {
  description = "Dominio principal (ej. tudominio.com) — pasar via TF_VAR_domain, no en tfvars"
  type        = string
  sensitive   = true
}

variable "tunnel_id" {
  description = "ID del tunnel existente en Cloudflare (Zero Trust > Networks > Tunnels)"
  type        = string
}

# Servicios a exponer. Key = subdominio, value = service interno
variable "services" {
  description = "Mapa de subdominio → backend interno (Traefik routea por host)"
  type        = map(string)
  default = {
    "home"    = "http://traefik:80"
    "n8n"     = "http://traefik:80"
    "mail"    = "http://traefik:80"
    "sign"    = "http://traefik:80"
    "social"  = "http://traefik:80"
    "vault"   = "http://traefik:80"
    "stats"   = "http://traefik:80"
    "tasks"   = "http://traefik:80"
    "metrics" = "http://traefik:80"
    "logs"    = "http://traefik:80"
  }
}

# DKIM tokens importados del state de AWS
variable "ses_dkim_tokens" {
  description = "3 tokens DKIM de AWS SES (output del módulo aws)"
  type        = list(string)
  default     = []
}

variable "ses_verification_token" {
  description = "Token de verificación de dominio SES"
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "Región de AWS donde está SES"
  type        = string
  default     = "us-east-1"
}
