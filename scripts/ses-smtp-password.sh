#!/usr/bin/env bash
# =============================================================================
# ses-smtp-password.sh — Convierte IAM Secret Access Key a SES SMTP Password
# =============================================================================
# AWS SES no acepta el IAM secret directamente como SMTP password;
# requiere derivar uno usando HMAC-SHA256 con la región.
#
# Uso:
#   ./ses-smtp-password.sh <SECRET_ACCESS_KEY> <REGION>
#
# Referencia oficial:
#   https://docs.aws.amazon.com/ses/latest/dg/smtp-credentials.html

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Uso: $0 <SECRET_ACCESS_KEY> <REGION>"
  echo "Ej:  $0 abc123... us-east-1"
  exit 1
fi

SECRET_KEY="$1"
REGION="$2"
DATE="11111111"
SERVICE="ses"
TERMINAL="aws4_request"
MESSAGE="SendRawEmail"
VERSION_BYTE=$(printf '\x04')

# Cálculo HMAC encadenado (AWS Signature v4 derivation)
sig_key=$(printf "AWS4%s" "$SECRET_KEY" | openssl dgst -sha256 -mac HMAC -macopt "key:AWS4$SECRET_KEY" -binary -hmac "AWS4$SECRET_KEY" <(printf "$DATE") 2>/dev/null | xxd -p -c 256)

# Python es más confiable para esto en macOS
python3 <<PYEOF
import hmac, hashlib, base64

secret = "$SECRET_KEY"
region = "$REGION"
date = "11111111"
service = "ses"
terminal = "aws4_request"
message = "SendRawEmail"
version = b'\x04'

def sign(key, msg):
    return hmac.new(key, msg.encode('utf-8'), hashlib.sha256).digest()

k_date = sign(("AWS4" + secret).encode('utf-8'), date)
k_region = sign(k_date, region)
k_service = sign(k_region, service)
k_terminal = sign(k_service, terminal)
k_message = sign(k_terminal, message)

signature_and_version = version + k_message
smtp_password = base64.b64encode(signature_and_version).decode('utf-8')

print(smtp_password)
PYEOF
