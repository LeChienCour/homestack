# 02 — Configuración de AWS SES paso a paso

## ¿Qué es y por qué lo necesitamos?

**AWS SES (Simple Email Service)** es el servicio de envío de emails de AWS. Listmonk lo usa para mandar tus newsletters/campañas porque:

1. **Reputación**: tus emails no caen en spam (vs enviar desde Gmail)
2. **Volumen**: puedes enviar miles sin que te bloqueen
3. **Costo**: $0.10 por cada 1000 emails (10,000 emails = $1)

## Antes de empezar

Necesitas:
- Cuenta AWS activa
- AWS CLI instalado: `brew install awscli`
- Tu dominio comprado (ej. en Cloudflare Registrar)

## Paso 1 — Crear IAM user dedicado

En lugar de usar tu user root de AWS (mala práctica), creamos uno con permisos mínimos.

**Opción A: vía Terraform (recomendado, ya está en el repo)**

```bash
cd terraform/aws
cp terraform.tfvars.example terraform.tfvars
# Edita terraform.tfvars con tu dominio
terraform init
terraform apply
```

Esto crea automáticamente:
- IAM user `homestack-listmonk-smtp`
- Identidad de dominio en SES
- 3 tokens DKIM
- Configuración MAIL FROM
- Access key + secret

**Opción B: manual desde consola AWS**

1. AWS Console → IAM → Users → Create user
2. Nombre: `homestack-listmonk-smtp`
3. Attach policy: `AmazonSESFullAccess` (o crea una custom con solo `ses:SendEmail`)
4. Security credentials → Create access key → Application running outside AWS
5. **Guarda el Access Key ID y Secret Access Key**

## Paso 2 — Verificar dominio en SES

Si usaste Terraform, los outputs te dan los tokens DKIM. Si lo haces manual:

1. AWS Console → SES → Verified identities → Create identity
2. Tipo: Domain
3. Domain: `tudominio.com`
4. Marca "Use a custom MAIL FROM domain": `mail.tudominio.com`
5. Easy DKIM: ✓ Enabled

SES te dará registros DNS que debes publicar. Si usas el Terraform de Cloudflare del repo, lo hace automáticamente leyendo el output del módulo aws.

## Paso 3 — Generar credenciales SMTP

**SES no acepta directamente tu IAM Secret Key como password SMTP.** Necesitas convertirlo con un algoritmo de derivación.

**Opción A: desde consola AWS (más fácil)**

1. AWS Console → SES → SMTP settings → Create SMTP credentials
2. Te da `SMTP Username` (parece IAM user) y `SMTP Password` (ya derivada)
3. Anótalas para el `.env`

**Opción B: convertir manualmente**

Usa el script del repo:
```bash
./scripts/ses-smtp-password.sh "TU_IAM_SECRET_KEY" "us-east-1"
```

Te devuelve el password SMTP listo para usar.

## Paso 4 — Salir del SES Sandbox

Por defecto, SES está en modo **sandbox**: solo puedes enviar a emails verificados.

Para producción debes pedir salida del sandbox:

1. AWS Console → SES → Account dashboard → Request production access
2. Llena el formulario:
   - **Mail type**: Marketing (o Transactional según tu caso)
   - **Website URL**: tu dominio
   - **Use case description**: explica que es un newsletter personal/de negocio, cómo manejas opt-in y opt-out
   - **Expected volume**: realista, ej. "Up to 5000 emails per month"
3. AWS responde en 24-48h

**Mientras tanto**, puedes probar Listmonk enviando solo a emails que verifiques manualmente en SES.

## Paso 5 — Configurar Listmonk

Después de tener todo:

1. Abre `https://mail.tudominio.com` (Listmonk)
2. Settings → SMTP → Add SMTP server
3. Configurar:
   - **Host**: `email-smtp.us-east-1.amazonaws.com`
   - **Port**: `587`
   - **Auth protocol**: Login
   - **Username**: tu SMTP user (del Paso 3)
   - **Password**: tu SMTP password (del Paso 3)
   - **TLS**: STARTTLS
   - **HELO hostname**: `mail.tudominio.com`
   - **Max conns**: 10
   - **Max msg retries**: 2
   - **Idle timeout**: 15s
   - **Wait timeout**: 5s

4. Click "Test" → debe enviar email de prueba

## Costos esperados

| Volumen mensual | Costo |
|---|---|
| 1,000 emails | $0.10 |
| 10,000 emails | $1.00 |
| 100,000 emails | $10.00 |
| 1M emails | $100 |

Más $0.10 por cada GB de datos adjuntos. Casi nada para uso personal.

## Verificar deliverability

Manda un email de prueba a [mail-tester.com](https://www.mail-tester.com/) y debes sacar **10/10**. Si no:

- ¿DKIM verificado? Revisa SES → Identities
- ¿SPF correcto? Debe ser `v=spf1 include:amazonses.com -all`
- ¿DMARC publicado? Revisa con `dig _dmarc.tudominio.com TXT`

## Monitoreo

AWS Console → SES → Account dashboard te muestra:
- Bounces rate (debe ser <5%)
- Complaints rate (debe ser <0.1%)

Si superas esos límites, SES suspende tu envío. Si tu lista tiene >5% bounces, revisa tu fuente de emails (¿compraste una lista? eso es ilegal y te van a banear).
