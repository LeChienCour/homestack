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

Externos: AWS SES (email), Ollama nativo (IA local), Cloudflare (DNS+tunnel), disco USB (backups).

## Estructura del repo

```
homestack/
├── CLAUDE.md                 # este archivo
├── README.md                 # guía de setup paso a paso
├── .env.example              # plantilla de variables
├── .sops.yaml                # config de encriptación
├── terraform/
│   ├── aws/                  # SES + IAM
│   └── cloudflare/           # tunnel + DNS + DKIM
├── compose/
│   ├── docker-compose.yml    # stack completo (13 servicios)
│   ├── traefik/              # config proxy
│   ├── postgres/init/        # crea las DBs
│   ├── homepage/             # config dashboard
│   └── n8n-workflows/        # workflow nota→ticket
├── mcp-vikunja/              # MCP server Python (FastMCP)
│   ├── src/server.py         # servidor con tools de tickets
│   ├── pyproject.toml
│   └── README.md
├── scripts/
│   ├── bootstrap.sh          # setup inicial
│   ├── backup.sh / restore.sh
│   ├── install-backup-cron.sh
│   └── ses-smtp-password.sh
└── docs/                     # 7 guías (Podman, SES, tunnel, Umami, troubleshooting, glosario, Ollama)
```

## Estado actual / pendientes

Lo que está HECHO:
- Repo completo generado (compose, terraform, scripts, docs)
- MCP server de Vikunja funcional (Python/FastMCP)
- Workflow n8n de ejemplo (nota → Ollama clasifica → Vikunja crea ticket)

Lo que FALTA (tareas para Cowork):
1. **Reemplazar `tudominio.com`** por el dominio real en todo el repo (Diego va a comprar uno en Cloudflare Registrar). Find/replace global.
2. **Probar el MCP server** contra una instancia real de Vikunja (ajustar si la API cambió).
3. **Ajustar el `projectMap`** del workflow n8n con los IDs reales de proyectos de Vikunja una vez creados.
4. **Verificar imágenes ARM64** de Postiz y Vikunja antes de desplegar (`docker manifest inspect`).
5. **Salir del SES sandbox** (trámite AWS de 24-48h).
6. Decidir si conectar el MCP de Vikunja vía stdio (Cowork local) o HTTP (remoto por el tunnel).

## Perfil de Diego (para calibrar respuestas)

- DevOps/Cloud Engineer, 6+ años AWS, experto en la nube AWS.
- Programa Python, nociones de NodeJS.
- Prefiere respuestas cortas, directas, con fuentes citadas.
- Valora honestidad sobre validación. Si algo es mala idea, decírselo.
- Negocio de fotografía: FOTOGRAMIA (photobooth de fin de semana).
- Estudiando para AWS DOP-C02.

## Convenciones

- Idioma: español.
- Secretos: nunca en texto plano en git. Usar SOPS+age o `.env` (gitignored).
- Generar passwords con `openssl rand`.
- Limits de RAM explícitos en cada container (16GB es el techo).
- Al agregar un servicio nuevo: (1) compose, (2) DB en init SQL si aplica, (3) DNS en terraform/cloudflare/variables.tf, (4) Homepage, (5) backup.sh.
