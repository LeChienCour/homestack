# =============================================================================
# Terraform — Cloudflare DNS + Ingress (tunnel pre-existente)
# =============================================================================
# Este módulo NO crea el tunnel — solo gestiona DNS records.
# El tunnel se crea una vez manualmente en Zero Trust > Networks > Tunnels.
# Pasar el tunnel ID como variable `tunnel_id`.

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
