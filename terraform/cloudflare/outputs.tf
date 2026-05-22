# =============================================================================
# Outputs — el más importante es tunnel_token para .env
# =============================================================================

output "tunnel_token" {
  description = "Token para cloudflared en docker-compose. Copiar a CLOUDFLARE_TUNNEL_TOKEN en .env"
  value       = cloudflare_tunnel.main.tunnel_token
  sensitive   = true
}

output "tunnel_id" {
  description = "ID del tunnel"
  value       = cloudflare_tunnel.main.id
}

output "tunnel_cname" {
  description = "CNAME target del tunnel"
  value       = "${cloudflare_tunnel.main.id}.cfargotunnel.com"
}

output "service_urls" {
  description = "URLs configuradas"
  value = {
    for subdomain, _ in var.services :
    subdomain => "https://${subdomain}.${var.domain}"
  }
}
