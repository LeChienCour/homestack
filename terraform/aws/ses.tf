# =============================================================================
# AWS SES — Verificación de dominio + DKIM
# =============================================================================
# Después de aplicar, debes agregar los registros DNS DKIM en Cloudflare
# (Terraform de cloudflare lo hace automáticamente leyendo este output).

# Identidad de dominio en SES
resource "aws_ses_domain_identity" "domain" {
  domain = var.domain
}

# DKIM: genera 3 CNAMEs que deben publicarse en DNS
resource "aws_ses_domain_dkim" "domain_dkim" {
  domain = aws_ses_domain_identity.domain.domain
}

# MAIL FROM custom (mejora deliverability)
resource "aws_ses_domain_mail_from" "mail_from" {
  domain           = aws_ses_domain_identity.domain.domain
  mail_from_domain = "mail.${var.domain}"
}

# Configuration Set para tracking de eventos (opcional pero recomendado)
resource "aws_ses_configuration_set" "main" {
  name = "homestack-listmonk"

  delivery_options {
    tls_policy = "Require"
  }

  reputation_metrics_enabled = true
}
