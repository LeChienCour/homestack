# =============================================================================
# DNS records — CNAMEs hacia el tunnel + DKIM/SPF de SES
# =============================================================================

# Un CNAME por cada subdominio → tunnel
resource "cloudflare_record" "service" {
  for_each = var.services

  zone_id = data.cloudflare_zone.main.id
  name    = each.key
  content = "${cloudflare_tunnel.main.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true  # Pasa por Cloudflare (oculta IP, da SSL gratis)
  ttl     = 1     # Auto cuando proxied=true
  comment = "Homestack tunnel route"
}

# -----------------------------------------------------------------------------
# AWS SES — registros DNS para deliverability
# -----------------------------------------------------------------------------

# 1. Verificación del dominio en SES
resource "cloudflare_record" "ses_verification" {
  count = var.ses_verification_token != "" ? 1 : 0

  zone_id = data.cloudflare_zone.main.id
  name    = "_amazonses"
  content = var.ses_verification_token
  type    = "TXT"
  ttl     = 600
  comment = "AWS SES domain verification"
}

# 2. DKIM: 3 CNAMEs
resource "cloudflare_record" "ses_dkim" {
  count = length(var.ses_dkim_tokens)

  zone_id = data.cloudflare_zone.main.id
  name    = "${var.ses_dkim_tokens[count.index]}._domainkey"
  content = "${var.ses_dkim_tokens[count.index]}.dkim.amazonses.com"
  type    = "CNAME"
  ttl     = 600
  proxied = false  # DKIM NUNCA proxied
  comment = "AWS SES DKIM ${count.index + 1}/3"
}

# 3. MX para MAIL FROM domain (mejora reputación)
resource "cloudflare_record" "ses_mail_from_mx" {
  count = var.ses_verification_token != "" ? 1 : 0

  zone_id  = data.cloudflare_zone.main.id
  name     = "mail"
  content  = "feedback-smtp.${var.aws_region}.amazonses.com"
  type     = "MX"
  priority = 10
  ttl      = 600
  proxied  = false
  comment  = "AWS SES MAIL FROM"
}

# 4. SPF para MAIL FROM domain
resource "cloudflare_record" "ses_mail_from_spf" {
  count = var.ses_verification_token != "" ? 1 : 0

  zone_id = data.cloudflare_zone.main.id
  name    = "mail"
  content = "v=spf1 include:amazonses.com -all"
  type    = "TXT"
  ttl     = 600
  proxied = false
  comment = "AWS SES SPF"
}

# 5. DMARC (recomendado para deliverability moderna)
resource "cloudflare_record" "dmarc" {
  count = var.ses_verification_token != "" ? 1 : 0

  zone_id = data.cloudflare_zone.main.id
  name    = "_dmarc"
  content = "v=DMARC1; p=quarantine; rua=mailto:dmarc@${var.domain}; ruf=mailto:dmarc@${var.domain}; fo=1"
  type    = "TXT"
  ttl     = 600
  proxied = false
  comment = "DMARC policy"
}
