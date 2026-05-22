# =============================================================================
# IAM — User para que Listmonk envíe vía SMTP de SES
# =============================================================================

resource "aws_iam_user" "listmonk_smtp" {
  name = "homestack-listmonk-smtp"
  path = "/homestack/"
}

# Política mínima: solo enviar emails vía SES
resource "aws_iam_user_policy" "listmonk_ses_send" {
  name = "ses-send-email"
  user = aws_iam_user.listmonk_smtp.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ses:FromAddress" = "${var.from_email_local_part}@${var.domain}"
          }
        }
      }
    ]
  })
}

# Access key para generar credenciales SMTP
resource "aws_iam_access_key" "listmonk_smtp" {
  user = aws_iam_user.listmonk_smtp.name
}

# Las credenciales SMTP de SES se derivan del IAM secret key.
# AWS provee un algoritmo específico: usa el output `smtp_password_helper`
# para ver el comando que las genera.
