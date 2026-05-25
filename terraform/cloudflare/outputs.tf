# =============================================================================
# Outputs — URLs configuradas
# =============================================================================

output "service_urls" {
  description = "URLs públicas configuradas"
  value = {
    for subdomain, _ in var.services :
    subdomain => "https://${subdomain}.${var.domain}"
  }
}

output "tunnel_cname" {
  description = "CNAME target del tunnel"
  value       = "${var.tunnel_id}.cfargotunnel.com"
}
