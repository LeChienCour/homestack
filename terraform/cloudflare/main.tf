# =============================================================================
# Terraform — Cloudflare Tunnel + DNS + Ingress
# =============================================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.40"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Lee la zona del dominio para obtener su ID
data "cloudflare_zone" "main" {
  name = var.domain
}
