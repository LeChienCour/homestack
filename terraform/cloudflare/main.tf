# =============================================================================
# Terraform — Cloudflare DNS + Tunnel Ingress (tunnel pre-existente)
# =============================================================================
# Este módulo NO crea el tunnel — gestiona DNS records + ingress rules.
# El tunnel se crea UNA SOLA VEZ manualmente en Zero Trust > Networks > Tunnels.
# Pasar el tunnel ID como TF_VAR_tunnel_id.

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.40"
    }
  }

  backend "s3" {
    bucket       = "homestack-tf-state"
    key          = "cloudflare/terraform.tfstate"
    region       = "us-east-1"
    profile      = "admin"
    use_lockfile = true  # Locking nativo S3 — no requiere DynamoDB (TF >= 1.10)
    encrypt      = true
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Lee la zona del dominio para obtener su ID
data "cloudflare_zone" "main" {
  name = var.domain
}
