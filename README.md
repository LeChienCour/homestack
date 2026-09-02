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
- Ollama nativo macOS → IA local (n8n workflows)
```

## Pre-requisitos

1. **Mac mini Apple Silicon** con 16GB RAM, macOS Sonoma o superior
2. **Dominio** en Cloudflare (Registrar o transferido)
3. **Cuenta AWS** con perfil `admin` configurado
4. **Disco USB externo** montado en `/Volumes/HomestackBackups`
5. **Homebrew** instalado

## Setup paso a paso

### 1. Instalar herramientas

```bash
brew install podman podman-compose vfkit terraform restic
```

> `vfkit` es obligatorio para el Apple Hypervisor en Apple Silicon.

### 2. Inicializar Podman Machine

> ⚠️ El repo debe estar en `/Volumes/Dock`. El flag `--volume` solo funciona en `machine init`.

```bash
podman machine init \
  --cpus 5 \
  --memory 6144 \
  --disk-size 30 \
  --volume /Volumes/Dock:/Volumes/Dock

podman machine start
```

### 3. Configurar credenciales

```bash
# AWS — perfil "admin" (no "homestack")
aws configure --profile admin

# Verificar
aws sts get-caller-identity --profile admin
```

### 4. Bootstrap del estado de Terraform (solo 1 vez)

Crea el bucket S3 que guarda el state de Terraform:

```bash
make tf-bootstrap
```

### 5. Configurar el archivo de variables

```bash
cp .env.example compose/.env
# Editar compose/.env con todos los valores reales
# Generar passwords seguros:
make gen-secrets
```

### 6. Crear tunnel de Cloudflare (manual, solo 1 vez)

1. Cloudflare → Zero Trust → Networks → Tunnels → **Create a tunnel** → Cloudflared
2. Nombre: `homestack-tunnel`
3. Copiar el **Tunnel Token** (base64 largo ~180 chars) → pegar en `compose/.env` como `CLOUDFLARE_TUNNEL_TOKEN`
4. Anotar el **Tunnel ID** (UUID, visible en la lista de tunnels)

### 7. Desplegar DNS con Terraform

```bash
# Exportar secrets (NUNCA commitear)
export TF_VAR_domain="tudominio.com"
export TF_VAR_cloudflare_api_token="tu-api-token"
export TF_VAR_cloudflare_account_id="tu-account-id"
export TF_VAR_tunnel_id="uuid-del-tunnel"

make tf-cf-apply
```

### 8. Desplegar SES con Terraform

```bash
export TF_VAR_domain="tudominio.com"
make tf-aws-apply
```

### 9. Configurar ingress rules del tunnel

En Cloudflare → Zero Trust → Tunnels → tu tunnel → **Public Hostname**, agregar para **cada servicio**:
- Subdomain: `home` / `n8n` / `mail` / etc.
- Domain: `tudominio.com`
- Service: `http://traefik:80`

### 10. Levantar el stack

```bash
make up
```

### 11. Verificar

```bash
make ps          # containers corriendo
make logs        # logs en tiempo real

# Acceder al dashboard
open https://home.tudominio.com
```

### 12. Configurar Beszel Agent

1. Abrir `https://metrics.tudominio.com` → Add System
2. Copiar la **public key** que genera la UI
3. Editar `compose/docker-compose.yml` → servicio `beszel-agent` → variable `KEY`
4. `make restart-svc SVC=beszel-agent`

## Comandos del día a día

```bash
make help          # lista completa de comandos
make up            # levantar todos los servicios
make down          # bajar todos
make ps            # estado de containers
make logs          # logs en vivo
make restart-svc SVC=n8n   # reiniciar un servicio
make pull          # actualizar imágenes
```

## Backups

Los backups se hacen automáticamente cada noche a las 3:00 AM al disco USB. Ver `scripts/backup.sh`.

```bash
# Instalar el cron
bash scripts/install-backup-cron.sh

# Restore manual
./scripts/restore.sh <snapshot-id>

# Listar snapshots
restic -r /Volumes/HomestackBackups/restic snapshots
```

## Autoarranque de Podman Machine

```bash
bash scripts/install-podman-autostart.sh
```

El script espera a que `/Volumes/Dock` esté montado antes de iniciar la VM.

## Costo estimado mensual

| Concepto | Costo USD |
|---|---|
| Dominio (.com Cloudflare Registrar) | $1 amortizado |
| Cloudflare plan free | $0 |
| AWS SES (10k emails/mes) | ~$1 |
| Electricidad Mac mini 24/7 | ~$3-5 |
| **Total** | **~$5-7** |

vs. SaaS equivalentes: **$150-200 USD/mes**.

## Documentación

- [docs/01-setup-podman.md](docs/01-setup-podman.md) — Setup de Podman en Mac (VM, socket, autoarranque)
- [docs/02-aws-ses-config.md](docs/02-aws-ses-config.md) — Configuración SES paso a paso
- [docs/03-cloudflare-tunnel.md](docs/03-cloudflare-tunnel.md) — Cloudflare Tunnel y DNS
- [docs/04-umami-snippet.md](docs/04-umami-snippet.md) — Cómo agregar tracking a FOTOGRAMIA
- [docs/05-troubleshooting.md](docs/05-troubleshooting.md) — Problemas comunes y soluciones
- [docs/06-glossary.md](docs/06-glossary.md) — Glosario de términos
- [docs/07-ollama-local-ai.md](docs/07-ollama-local-ai.md) — Ollama IA local + integración con n8n

## Mantenimiento

```bash
# Updates mensuales
make pull && make up

# Verificar backups
restic -r /Volumes/HomestackBackups/restic snapshots
```
