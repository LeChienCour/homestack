# 03 — Cloudflare Tunnel: cómo funciona y cómo configurarlo

## ¿Qué es Cloudflare Tunnel?

Expone servicios locales a internet **sin abrir puertos en el router**. El Mac mini hace una conexión SALIENTE hacia Cloudflare; Cloudflare hace de proxy del tráfico entrante.

**Con Cloudflare Tunnel:**
```
Internet → Cloudflare (WAF, DDoS, SSL) → tunnel cifrado ← Mac mini conecta hacia afuera
           ✓ Router sin puertos abiertos, IP oculta
```

## Dos valores importantes — no confundirlos

| Valor | Formato | Dónde se usa |
|---|---|---|
| **Tunnel ID** | UUID: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` | DNS CNAMEs, Terraform `tunnel_id` |
| **Tunnel Token** | Base64 ~180 chars: `eyJhIjoiXXh...` | `.env` → `CLOUDFLARE_TUNNEL_TOKEN` |

> ⚠️ Son valores distintos. Poner el UUID en `.env` da error: `Provided Tunnel token is not valid`.

## Setup del tunnel (hecho manualmente)

Terraform **NO crea el tunnel** — solo gestiona los DNS CNAMEs. El tunnel se creó manualmente:

1. Cloudflare Dashboard → Zero Trust → Networks → Tunnels → **Create a tunnel**
2. Tipo: Cloudflared → nombre: `homestack-tunnel`
3. Copiar el **token** (base64 largo, ~180 chars) → pegar en `compose/.env`:
   ```
   CLOUDFLARE_TUNNEL_TOKEN=eyJhIjoiXXh...token-largo
   ```
4. Copiar el **Tunnel ID** (UUID) → se usa en Terraform y se exporta como env var

## Configurar ingress rules (hostnames públicos)

El tunnel debe saber a dónde reenviar cada hostname. En Cloudflare Zero Trust:

1. Tunnels → tu tunnel → **Public Hostname** → Add a public hostname
2. Para **cada servicio**, agregar:
   - Subdomain: `home`, `n8n`, `mail`, etc.
   - Domain: `tudominio.com`
   - Service: `http://traefik:80`
3. Repetir para todos los subdominios (home, n8n, mail, sign, social, vault, stats, tasks, metrics, logs)

> Sin esto el tunnel responde `404` en todos los hostnames aunque esté conectado.

## Setup de DNS con Terraform

Terraform crea los CNAMEs que apuntan al tunnel. Requiere:

```bash
# 1. Bootstrap S3 backend (solo 1 vez)
make tf-bootstrap

# 2. Exportar secrets como variables de entorno
export TF_VAR_domain="tudominio.com"           # NUNCA committed al repo
export TF_VAR_cloudflare_api_token="..."
export TF_VAR_cloudflare_account_id="..."
export TF_VAR_tunnel_id="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"   # UUID del tunnel

# 3. Aplicar
make tf-cf-apply
```

Terraform crea:
- 11 CNAMEs: `home`, `n8n`, `mail`, `sign`, `social`, `vault`, `stats`, `tasks`, `metrics`, `logs`, `dozzle`
- Todos apuntan a `<tunnel-id>.cfargotunnel.com`

### Obtener los valores

**API Token:**
- Cloudflare → My Profile → API Tokens → Create Token
- Permisos: `Zone:DNS:Edit` para tu zona

**Account ID:**
- URL del dashboard: `https://dash.cloudflare.com/<ACCOUNT_ID>/...`

**Tunnel ID:**
- Zero Trust → Networks → Tunnels → tu tunnel → ID visible en la lista

**Tunnel Token:**
- Zero Trust → Networks → Tunnels → tu tunnel → Configure → token (base64 largo)

## Verificar que el tunnel funciona

```bash
# Logs del container cloudflared
podman logs cloudflared | grep -v precheck

# Debe mostrar:
# INF Registered tunnel connection connIndex=0 location=...
# INF Registered tunnel connection connIndex=1 location=...
# (4 conexiones = sano)
```

En Cloudflare dashboard → Zero Trust → Tunnels: debe aparecer **Healthy** (verde).

## Verificar que los servicios responden

```bash
curl -I https://home.tudominio.com
# Debe devolver headers de Cloudflare:
# server: cloudflare
# cf-ray: ...
```

## Troubleshooting

### "Provided Tunnel token is not valid"
Pusiste el **Tunnel ID** (UUID) en vez del **Tunnel Token** (base64).  
Fix: Zero Trust → Tunnels → tu tunnel → Configure → copiar el token largo → actualizar `.env` → `podman-compose up -d --force-recreate cloudflared`

### "Updated to new configuration … http_status:404"
Tunnel conectado pero sin ingress rules configuradas.  
Fix: agregar Public Hostnames en Zero Trust (ver sección arriba).

### "DNS_PROBE_FINISHED_NXDOMAIN"
CNAMEs tardan ~1 min en propagarse.  
Verificar: `dig home.tudominio.com CNAME` — debe responder `<tunnel-id>.cfargotunnel.com`

### "Error 502 Bad Gateway"
cloudflared conectado pero Traefik no responde.  
`podman logs traefik` — ¿está corriendo?

### "Error 530"
cloudflared no está conectado al edge.  
`podman logs cloudflared` — revisar token. Zero Trust → Tunnels: debe estar "Healthy".

## Agregar servicio nuevo

1. En `terraform/cloudflare/variables.tf`, agregar entrada en `services`
2. `make tf-cf-apply`
3. En Zero Trust → Tunnels → Public Hostname → agregar el nuevo subdominio → `http://traefik:80`
4. En `docker-compose.yml`, agregar labels Traefik al container

## Plan free vs paid

El plan **free** de Cloudflare es suficiente para uso personal:
- Bandwidth ilimitado
- DDoS protection + WAF
- SSL gratis
- 50 tunnels por cuenta
