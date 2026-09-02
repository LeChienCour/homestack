# CLAUDE.md — Contexto del proyecto Homestack

> Este archivo le da a Claude (en Cowork o Claude Code) el contexto completo del proyecto.
> Léelo primero antes de trabajar en este repo.

## Qué es este proyecto

Stack personal self-hosted que corre en un **Mac mini Apple Silicon de 16GB RAM**, para reemplazar SaaS de pago con software libre. Es un hobby/proyecto personal de Diego (DevOps/Cloud Engineer), NO es trabajo de cliente. Trabajo en solitario, sin necesidad de colaboración multiusuario.

## Decisiones de arquitectura ya tomadas (NO recablear sin razón)

1. **Orquestación: Podman Compose, NO Kubernetes.** Se evaluó k3s pero se descartó: para single-node personal es sobreingeniería y consume RAM extra (la VM de Colima costaba ~2GB vs ~500MB de Podman Machine). El objetivo es *usar* las apps, no practicar k8s.

2. **Sin Raspberry Pi por ahora.** Se consideró un nodo edge en RPi 4 pero se pospuso. Todo vive en el Mac mini.

3. **Reverse proxy: Traefik** (no Caddy ni Nginx Proxy Manager). Routing por hostname, config declarativa.

4. **Exposición: Cloudflare Tunnel** (cloudflared como container). Sin abrir puertos en el router. SSL automático de Cloudflare.

5. **Postgres compartido** (1 instancia, múltiples DBs), NO uno por app. Ahorra ~2GB RAM, obligatorio con 16GB.

6. **Email: AWS SES.** Diego eligió SES sobre Resend/Brevo porque quiere usar su expertise AWS. Gestionado por Terraform (dominio, DKIM, IAM user con permisos mínimos).

7. **Backups: disco USB externo + Restic** (NO S3/Glacier). Disco debe llamarse `HomestackBackups`. Cron diario 3 AM vía launchd.

8. **Notas/conocimiento: Notion cloud** (no self-hosted). Se descartó AppFlowy (frágil en ARM, pesado) y Affine. Notion ya tiene MCP oficial conectado.

9. **Tickets/proyectos: Vikunja.** Se eligió sobre Plane (muy pesado, multi-container) y Kanboard. Ligero (~150MB), kanban + subtareas + API REST. DB en el Postgres compartido.

10. **IA local: Ollama NATIVO en macOS** (no en container). Razón: Podman en Mac no accede al GPU Metal; en container correría en CPU. Modelo principal `llama3.2:3b`, con `qwen2.5:7b` para tareas de más calidad.

11. **MCP server de Vikunja: propio, en Python/FastMCP.** Existe uno de comunidad (`democratize-technology/vikunja-mcp`, TypeScript) pero Diego prefirió uno propio para control real y para aprender FastMCP (útil para su talk de AWS Community Day 2026).

## Stack completo (servicios)

| Servicio | Subdominio | Función | RAM aprox |
|---|---|---|---|
| Traefik | (interno) | Reverse proxy | 80MB |
| cloudflared | (interno) | Tunnel | 30MB |
| Postgres | (interno) | DB compartida | 300MB |
| Redis | (interno) | Cache (Postiz) | 50MB |
| n8n | n8n. | Automatización | 400MB |
| Listmonk | mail. | Email marketing (→AWS SES) | 200MB |
| Docuseal | sign. | Firma electrónica | 400MB |
| Postiz | social. | Redes sociales | 800MB |
| Vaultwarden | vault. | Contraseñas | 50MB |
| Umami | stats. | Analytics (trackea FOTOGRAMIA) | 150MB |
| Vikunja | tasks. | Tickets/proyectos | 150MB |
| Homepage | home. | Dashboard | 50MB |
| Beszel | metrics. | Monitoring | 50MB |
| Dozzle | logs. | Logs en vivo | 20MB |
| SocialTrace | track. | Tracking manual redes (FOTOGRAMIA) — repo hermano `../socialtrace` | 450MB |

**RAM total containers ≈ 3.230 MB** (~3.2 GB). Con 16 GB en el Mac mini sobra margen. Antes de agregar servicio nuevo, verificar que la suma no supere ~12 GB (dejar 4 GB para macOS + Podman Machine + Ollama).

Externos: AWS SES (email), Ollama nativo (IA local), Cloudflare (DNS+tunnel), disco USB (backups).

### SocialTrace — integración desde repo hermano

Vive en `../socialtrace` (repo separado, no submódulo). Los 3 servicios
(`socialtrace-backend`, `socialtrace-frontend`, `socialtrace-caddy`) se
buildean en `compose/docker-compose.yml` con `build: ../../socialtrace/*`
— requiere que ambos repos sean hermanos en el filesystem. Se conserva el
Caddy propio del proyecto (routing interno `/api` → backend, resto →
frontend) como único punto expuesto a Traefik; backend/frontend usan
aliases de red (`backend`/`frontend`) porque el Caddyfile de socialtrace
los referencia hardcodeados. DB `socialtrace` en el Postgres compartido
(no Postgres propio). Sin backup sidecar propio — `backup.sh` de
homestack ya cubre la DB vía `pg_dumpall`.

### Ollama — conectividad desde containers

Ollama corre **nativo en macOS**, puerto `11434`. Los containers de Podman lo alcanzan via:
```
http://host.docker.internal:11434
```
Usar esta URL en n8n (nodo Ollama), en workflows, y en cualquier variable de entorno que apunte a la IA local. **No usar `localhost`** desde dentro de un container (no funciona en Podman/Docker en Mac).

## Estructura del repo

```
homestack/
├── CLAUDE.md                 # este archivo
├── README.md                 # guía de setup paso a paso
├── Makefile                  # todos los comandos operacionales (make help)
├── .env.example              # plantilla de variables
├── .sops.yaml                # placeholder — ver nota abajo
├── terraform/
│   ├── aws/                  # SES + IAM
│   └── cloudflare/           # tunnel + DNS + DKIM
├── compose/
│   ├── docker-compose.yml    # stack completo (13 servicios)
│   ├── .env                  # secretos reales (gitignored, NO commitear)
│   ├── traefik/              # config proxy
│   ├── postgres/init/        # crea las DBs
│   ├── homepage/             # config dashboard
│   └── n8n-workflows/        # workflow nota→ticket
├── mcp-vikunja/              # MCP server Python (FastMCP)
│   ├── src/server.py         # servidor con tools de tickets
│   ├── pyproject.toml        # requiere python >=3.12, uv para gestión
│   └── README.md
├── scripts/
│   ├── bootstrap.sh          # setup inicial
│   ├── backup.sh / restore.sh
│   ├── install-backup-cron.sh
│   └── ses-smtp-password.sh
└── docs/                     # 7 guías (Podman, SES, tunnel, Umami, troubleshooting, glosario, Ollama)
```

### Nota sobre SOPS
`.sops.yaml` existe como placeholder pero **no está configurado ni es necesario**. Proyecto personal en solitario: `compose/.env` gitignored es suficiente. No sugerir SOPS a menos que Diego lo pida explícitamente.

## Estado actual / pendientes

Lo que está HECHO:
- Repo completo generado (compose, terraform, scripts, docs)
- Makefile con todos los comandos operacionales (`make help`)
- MCP server de Vikunja funcional (Python/FastMCP)
- Workflow n8n de ejemplo (nota → Ollama clasifica → Vikunja crea ticket)
- MCP Vikunja: decisión tomada → **stdio local** (Claude Code en el Mac mini)
- Terraform refactorizado: S3 backend (`homestack-tf-state`), perfil AWS `admin`, secretos via env vars
- Terraform Cloudflare: solo DNS CNAMEs (tunnel creado manualmente, no por TF)
- S3 state bucket creado (`make tf-bootstrap` ejecutado)
- Terraform AWS (SES) aplicado
- Terraform Cloudflare (DNS) aplicado
- Podman Machine recreada con `--volume /Volumes/Dock:/Volumes/Dock`
- Socket path corregido a `/run/user/501/podman/podman.sock` en compose
- `security_opt: label=disable` en traefik, dozzle, beszel-agent
- Stack levantado: 12/14 containers running
- cloudflared: 4 conexiones registradas al edge ✓

Lo que FALTA:
1. **Aplicar `cloudflare_tunnel_config`** — `make tf-cf-apply` configura las ingress rules del tunnel via Terraform (ya no es manual)
2. **Configurar Beszel agent key** — abrir metrics.dominio → Add System → copiar key → actualizar `docker-compose.yml` → `make restart-svc SVC=beszel-agent`
3. **Probar el MCP server** contra instancia real de Vikunja
4. **Ajustar `projectMap`** del workflow n8n con IDs reales de Vikunja
5. **Salir del SES sandbox** (trámite AWS de 24-48h, solo 1 vez)
6. **Instalar autoarranque Podman** — `bash scripts/install-podman-autostart.sh`
7. **Deshabilitar registro de Vikunja** tras crear cuenta (`VIKUNJA_SERVICE_ENABLEREGISTRATION=false`)

## Detalles de infraestructura (no obvios)

### Podman Machine
- `vfkit` requerido: `brew install vfkit`
- Socket rootless: `/run/user/501/podman/podman.sock` (UID 501)
- SELinux en la VM: requiere `security_opt: [label=disable]` en containers que usan el socket
- **La VM (applehv) NO tiene montado `/Volumes/Dock`** — solo comparte por defecto `/Users`, `/private`, `/var/folders`. `podman machine set` no admite agregar `--volume` a una VM ya creada (solo en `init`), y no se va a recrear la VM (perdería los volúmenes nombrados de otros stacks corriendo, ej. Atalaya). Por eso `traefik`, `postgres`, `homepage` y `temporal` NO usan bind mount para su config — la config se hornea en la imagen vía `build:` + Dockerfile propio (`compose/traefik/Dockerfile`, `compose/postgres/Dockerfile`, `compose/homepage/Dockerfile`, `compose/temporal/Dockerfile`). `podman build` sí funciona sin el mount porque el build-context se manda por la API (streaming), a diferencia de un bind mount que necesita que la VM vea la ruta del host directamente.
- **Al editar `traefik.yml`, `traefik/dynamic/*`, `postgres/init/*.sql`, `homepage/*`, o `temporal/dynamicconfig/*`:** correr `make rebuild-configs` (rebuild + recreate de esos 4 containers) — un simple restart no basta, hay que rebuildear la imagen.
- El resto de los servicios (n8n, vikunja, vaultwarden, etc.) no tienen este problema: usan solo volúmenes nombrados (viven dentro del disco de la VM) o `env`, no bind mounts a `/Volumes/Dock`.
- **Ojo con `--force-recreate` en servicios individuales**: podman-compose puede cascadear el recreate a dependencias no pedidas (ej. `postgres`, `n8n`, `temporal` se recrearon solos al pedir `--force-recreate` de `socialtrace-*`). Un container recreado (no solo reiniciado) puede además exponer un mismatch de ownership en su volumen si el volumen se creó bajo otro nombre de proyecto — Vikunja usa `/app/vikunja/files` (uid 1000 dentro del container) y el volumen real es `compose_vikunja_files` (prefijo `compose_`, no `homestack_`, por el nombre del directorio donde corre `podman-compose`). Si un container con esta pinta crashea en loop con `permission denied` tras un recreate, fijate el volumen real con `podman inspect <container> --format '{{json .Mounts}}'` (NO asumas el prefijo) y arreglá el ownership desde DENTRO de la VM con root real, no con `podman run --rm -v ... alpine chown` desde el host (cada `podman run` ad-hoc puede caer en un mapeo de userns distinto al del container real y no arregla nada):
  ```
  podman machine ssh podman-machine-default
  sudo chown <uid-mapeado>:<gid-mapeado> /var/home/core/.local/share/containers/storage/volumes/<volumen-real>/_data
  ```
  El uid/gid mapeado sale del mensaje de error del container (ej. Vikunja loguea "process host uid=100999" y "dir owner uid=X gid=Y" esperados).

### Terraform
- Perfil AWS: `admin` (no "homestack")
- S3 backend bucket: `homestack-tf-state` (region us-east-1)
- State files: `cloudflare/terraform.tfstate` y `aws/terraform.tfstate`
- Secrets via env vars: `TF_VAR_domain`, `TF_VAR_cloudflare_api_token`, `TF_VAR_cloudflare_account_id`, `TF_VAR_tunnel_id`
- ⚠️ Dominio NUNCA en archivos committed. Solo en `.env` (gitignored) y variables de shell.

### Cloudflare Tunnel
- Tunnel creado manualmente en CF Zero Trust (no por Terraform)
- Tunnel ID (UUID) ≠ Tunnel Token (base64 ~180 chars)
- Token va en `compose/.env` → `CLOUDFLARE_TUNNEL_TOKEN`
- Ingress rules configuradas en CF Zero Trust → Public Hostnames (no en terraform)

## Checklist primer arranque (orden obligatorio)

```
1. Comprar dominio y apuntar NS a Cloudflare
2. brew install podman podman-compose vfkit terraform restic
3. podman machine init --cpus 5 --memory 6144 --disk-size 30 --volume /Volumes/Dock:/Volumes/Dock
4. podman machine start
5. cp .env.example compose/.env  →  llenar todos los valores (make gen-secrets ayuda)
6. make tf-bootstrap   (crea bucket S3 para state)
7. export TF_VAR_domain=... TF_VAR_cloudflare_api_token=... TF_VAR_cloudflare_account_id=... TF_VAR_tunnel_id=...
8. make tf-aws-apply
9. make tf-cf-apply
10. En CF Zero Trust → crear tunnel → copiar token → pegar en compose/.env → anotar Tunnel ID
11. En CF Zero Trust → Public Hostnames → agregar cada subdominio apuntando a http://traefik:80
12. make up
13. Abrir Beszel UI → agregar sistema → copiar key → actualizar beszel-agent en compose
14. make restart-svc SVC=beszel-agent
15. Crear cuenta en Vikunja → deshabilitar registro (VIKUNJA_SERVICE_ENABLEREGISTRATION=false)
16. Probar MCP server: make mcp-install && make mcp-run
17. bash scripts/install-podman-autostart.sh
```

## Perfil de Diego (para calibrar respuestas)

- DevOps/Cloud Engineer, 6+ años AWS, experto en la nube AWS.
- Programa Python, nociones de NodeJS.
- Prefiere respuestas cortas, directas, con fuentes citadas.
- Valora honestidad sobre validación. Si algo es mala idea, decírselo.
- Negocio de fotografía: FOTOGRAMIA (photobooth de fin de semana).
- Estudiando para AWS DOP-C02.

## MCP Vikunja — configuración Claude Code (stdio)

Agregar en `~/.claude/claude_desktop_config.json` (o config de Claude Code):

```json
{
  "mcpServers": {
    "vikunja": {
      "command": "uv",
      "args": ["run", "--directory", "/ruta/a/homestack/mcp-vikunja", "python", "src/server.py"],
      "env": {
        "VIKUNJA_URL": "https://tasks.<dominio>",
        "VIKUNJA_TOKEN": "<api-token-de-vikunja>"
      }
    }
  }
}
```

Obtener `VIKUNJA_TOKEN`: Vikunja UI → Settings → API Tokens → crear token.

## Herramientas requeridas

| Herramienta | Versión mínima | Uso |
|---|---|---|
| podman / podman-compose | 5.x / 1.x | orquestación containers |
| vfkit | latest | Apple Hypervisor para Podman Machine (ARM) |
| terraform | >=1.10 | infra AWS + Cloudflare (S3 lockfile nativo) |
| python | >=3.12 | MCP server Vikunja |
| uv | latest | gestor deps Python |
| restic | >=0.16 | backups |
| age / sops | — | **no requerido** (ver nota SOPS) |

## Convenciones

- Idioma: español.
- Secretos: `compose/.env` gitignored. Nunca commitear credenciales.
- Generar passwords con `openssl rand` o `make gen-secrets`.
- Limits de RAM explícitos en cada container (16 GB es el techo).
- Al agregar un servicio nuevo: (1) compose, (2) DB en init SQL si aplica, (3) DNS en terraform/cloudflare/variables.tf, (4) Homepage widget, (5) backup.sh incluir volumen, (6) sumar RAM a la tabla del stack.
- Comandos del día a día vía `make`. Ver `make help` para lista completa.
