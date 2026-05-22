# =============================================================================
# Outputs — para usar en Cloudflare TF y en .env
# =============================================================================

output "ses_domain_verification_token" {
  description = "Token TXT para verificar el dominio en SES (publicar como _amazonses.tudominio.com)"
  value       = aws_ses_domain_identity.domain.verification_token
}

output "ses_dkim_tokens" {
  description = "3 tokens DKIM. Publicar como CNAMEs: <token>._domainkey.tudominio.com → <token>.dkim.amazonses.com"
  value       = aws_ses_domain_dkim.domain_dkim.dkim_tokens
}

output "ses_mail_from_mx_record" {
  description = "Registro MX para MAIL FROM domain"
  value       = "mail.${var.domain} → feedback-smtp.${var.aws_region}.amazonses.com (prio 10)"
}

output "ses_mail_from_spf_record" {
  description = "Registro TXT SPF para MAIL FROM domain"
  value       = "v=spf1 include:amazonses.com -all"
}

output "smtp_endpoint" {
  description = "SMTP endpoint de SES para Listmonk"
  value       = "email-smtp.${var.aws_region}.amazonaws.com"
}

output "smtp_username" {
  description = "Username SMTP (= IAM access key ID)"
  value       = aws_iam_access_key.listmonk_smtp.id
  sensitive   = true
}

output "smtp_password_helper" {
  description = "Comando para generar el SMTP password desde el secret key IAM"
  value       = "Ejecuta: aws sts get-caller-identity && echo 'Usa el SES SMTP credential generator en consola AWS, o este script: https://docs.aws.amazon.com/ses/latest/dg/smtp-credentials.html#smtp-credentials-convert'"
}

output "iam_secret_for_smtp_conversion" {
  description = "Secret access key (convertir a SMTP password con script)"
  value       = aws_iam_access_key.listmonk_smtp.secret
  sensitive   = true
}

# Output de la dirección from para usar en .env
output "from_email" {
  description = "Email FROM para Listmonk"
  value       = "${var.from_email_local_part}@${var.domain}"
}
