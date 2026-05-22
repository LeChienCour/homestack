# =============================================================================
# Cloudflare Tunnel — recurso principal
# =============================================================================

# Secret para autenticar el tunnel
resource "random_id" "tunnel_secret" {
  byte_length = 35
}

# Tunnel propiamente dicho
resource "cloudflare_tunnel" "main" {
  account_id = var.cloudflare_account_id
  name       = var.tunnel_name
  secret     = random_id.tunnel_secret.b64_std
}

# Configuración del tunnel: cómo enrutar cada hostname al backend interno
resource "cloudflare_tunnel_config" "main" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_tunnel.main.id

  config {
    # Reglas de ingress: cada hostname mapea a un servicio interno
    dynamic "ingress_rule" {
      for_each = var.services
      content {
        hostname = "${ingress_rule.key}.${var.domain}"
        service  = ingress_rule.value
      }
    }

    # Fallback obligatorio: todo lo demás retorna 404
    ingress_rule {
      service = "http_status:404"
    }
  }
}
