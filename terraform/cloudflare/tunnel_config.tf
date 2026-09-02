# =============================================================================
# Tunnel ingress rules — Public Hostnames del tunnel existente
# =============================================================================
# Configura qué hostname va a qué backend.
# El catch-all al final es obligatorio (responde 404 a hostnames no definidos).
# Reemplaza la configuración manual de Zero Trust > Tunnels > Public Hostname.

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "homestack" {
  account_id = var.cloudflare_account_id
  tunnel_id  = var.tunnel_id

  config {
    # Regla por cada servicio: hostname → Traefik → container correcto
    dynamic "ingress_rule" {
      for_each = var.services
      content {
        hostname = "${ingress_rule.key}.${var.domain}"
        service  = ingress_rule.value
      }
    }

    # Catch-all obligatorio — debe ser la última regla, sin hostname
    ingress_rule {
      service = "http_status:404"
    }
  }
}
