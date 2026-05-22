# Homestack — Self-hosted Personal Stack

Stack personal de servicios self-hosted corriendo en Mac mini (Apple Silicon) con Podman, expuesto vía Cloudflare Tunnel.

## Servicios incluidos

| Servicio | URL | Función | Reemplaza |
|---|---|---|---|
| Homepage | `home.tudominio.com` | Dashboard central | — |
| n8n | `n8n.tudominio.com` | Automatización de flujos | Zapier |
| Listmonk | `mail.tudominio.com` | Email marketing | Mailchimp |
| Docuseal | `sign.tudominio.com` | Firma electrónica | DocuSign |
| Postiz | `social.tudominio.com` | Gestión redes sociales | Buffer |
| Vikunja | `tasks.tudominio.com` | Tickets y proyectos | Jira/Trello |
| Vaultwarden | `vault.tudominio.com` | Gestor de contraseñas | Bitwarden |
| Umami | `stats.tudominio.com` | Web analytics | Google Analytics |
| Beszel | `metrics.tudominio.com` | Monitoring del stack | — |
| Dozzle | `logs.tudominio.com` | Logs en tiempo real | — |

## Arquitectura

```
Internet
   ↓
Cloudflare (DNS + WAF, plan free)
   ↓ tunnel cifrado (sin puertos abiertos)
cloudflared (container en Mac mini)
   ↓
Traefik (routing por hostname)
   ↓
[n8n, listmonk, docuseal, postiz, vaultwarden, umami, homepage, beszel, dozzle]
   ↓
Postgres + Redis (compartidos)
   ↓
Disco USB externo (backups Restic, encriptados)

Externos:
- AWS SES → envío de emails (Listmonk)
```

## Pre-requisitos

1. **Mac mini Apple Silicon** con 16GB RAM, macOS Sonoma o superior
2. **Dominio comprado** y agregado a Cloudflare (recomendado: Cloudflare Registrar)
3. **Cuenta AWS** con permisos para crear IAM users, SES, Route53 (opcional)
4. **Disco USB externo** (mínimo 100GB) montado permanentemente
5. **Homebrew** instalado

## Setup paso a paso

### 1. Instalar herramientas

```bash
# Tooling base
brew install podman podman-compose terraform sops age cloudflared restic

# Iniciar Podman Machine (la VM Linux ligera)
podman machine init --cpus 4 --memory 8192 --disk-size 80
podman machine start
```

### 2. Configurar AWS

Crea un IAM user con acceso programático y políticas para SES + Route53 (si tu dominio está en Route53). Anota `AWS_ACCESS_KEY_ID` y `AWS_SECRET_ACCESS_KEY`.

```bash
aws configure --profile homestack
```

### 3. Configurar Cloudflare

1. Compra dominio en Cloudflare Registrar (o transfiere uno existente).
2. Crea un API token con permisos:
   - `Zone:DNS:Edit` (para tu zona)
   - `Account:Cloudflare Tunnel:Edit`
3. Anota el token y el `Account ID` (visible en la URL del dashboard).

### 4. Configurar SOPS para secretos

```bash
# Generar llave age
age-keygen -o ~/.config/sops/age/keys.txt

# Anotar la clave pública (age1...) y configurar
cat ~/.config/sops/age/keys.txt | grep "public key"
```

Edita `.sops.yaml` con tu clave pública.

### 5. Crear archivo de variables

```bash
cp .env.example .env
# Edita .env con tus valores reales
```

### 6. Desplegar infraestructura con Terraform

```bash
cd terraform/aws
terraform init
terraform apply

cd ../cloudflare
terraform init
terraform apply
# Anota el TUNNEL_TOKEN del output, lo necesitas para el .env
```

### 7. Levantar el stack

```bash
cd compose
podman-compose up -d
```

### 8. Verificar

```bash
# Estado de containers
podman ps

# Logs si algo falla
podman logs <nombre-container>

# Acceder a Homepage
open https://home.tudominio.com
```

## Backups

Los backups se hacen automáticamente cada noche a las 3:00 AM al disco USB externo. Ver `scripts/backup.sh` y `scripts/install-backup-cron.sh`.

Restore manual:
```bash
./scripts/restore.sh <snapshot-id>
```

## Costo estimado mensual

| Concepto | Costo USD |
|---|---|
| Dominio (.com Cloudflare) | $1 amortizado |
| Cloudflare plan free | $0 |
| AWS SES (10k emails/mes) | ~$1 |
| Electricidad Mac mini 24/7 | ~$3-5 |
| **Total** | **~$5-7** |

vs. SaaS equivalentes que costarían **$150-200 USD/mes**.

## Documentación

- [docs/01-setup-podman.md](docs/01-setup-podman.md) — Setup detallado de Podman en Mac
- [docs/02-aws-ses-config.md](docs/02-aws-ses-config.md) — Configuración SES paso a paso
- [docs/03-cloudflare-tunnel.md](docs/03-cloudflare-tunnel.md) — Cloudflare Tunnel y DNS
- [docs/04-umami-snippet.md](docs/04-umami-snippet.md) — Cómo agregar tracking a FOTOGRAMIA
- [docs/05-troubleshooting.md](docs/05-troubleshooting.md) — Problemas comunes
- [docs/06-glossary.md](docs/06-glossary.md) — Glosario de términos

## Mantenimiento

- **Updates mensuales:** `podman-compose pull && podman-compose up -d`
- **Restart Mac mini:** los containers se levantan automáticamente con systemd (Podman)
- **Verificar backups:** `restic -r /Volumes/Backups/restic snapshots`
