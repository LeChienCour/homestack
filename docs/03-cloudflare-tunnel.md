# 03 — Cloudflare Tunnel: cómo funciona y cómo configurarlo

## ¿Qué es Cloudflare Tunnel?

Es una forma de exponer tus servicios locales a internet **sin abrir puertos en tu router**. Tu Mac mini hace una conexión SALIENTE hacia Cloudflare, y Cloudflare actúa como proxy del tráfico entrante.

**Sin Cloudflare Tunnel:**
```
Internet → router (puerto 80/443 abierto) → Mac mini
           ⚠ Cualquiera puede atacarte directamente
```

**Con Cloudflare Tunnel:**
```
Internet → Cloudflare (WAF, DDoS, SSL) → tunnel cifrado ← Mac mini conecta hacia afuera
           ✓ Router sin puertos abiertos, IP oculta
```

## Ventajas

1. **Sin puertos abiertos**: tu router queda 100% cerrado
2. **SSL automático**: Cloudflare provee certificados, no necesitas Let's Encrypt
3. **Protección DDoS** y WAF incluidos en plan free
4. **IP oculta**: tu IP residencial nunca se ve
5. **Funciona detrás de CGNAT**: aunque tu ISP no te dé IP pública

## Setup paso a paso

### Paso 1 — Comprar dominio en Cloudflare Registrar

1. Cloudflare → Domain Registration → Register Domain
2. Buscar y comprar (precio de costo, sin markup)
3. El dominio queda automáticamente en Cloudflare DNS

### Paso 2 — Generar API Token

1. Cloudflare Dashboard → My Profile → API Tokens → Create Token
2. Template: "Edit zone DNS" o custom con:
   - `Zone:DNS:Edit` para tu zona
   - `Account:Cloudflare Tunnel:Edit`
3. Copiar el token (se muestra UNA SOLA VEZ)

### Paso 3 — Obtener Account ID

Está en la URL cuando entras al dashboard:
```
https://dash.cloudflare.com/<ACCOUNT_ID>/...
```

### Paso 4 — Aplicar Terraform

```bash
cd terraform/cloudflare
cp terraform.tfvars.example terraform.tfvars
# Edita terraform.tfvars con tus valores
terraform init
terraform apply
```

Terraform crea:
- 1 tunnel con nombre `homestack-tunnel`
- 9 CNAMEs apuntando al tunnel (home, n8n, mail, sign, social, vault, stats, metrics, logs)
- Reglas de ingress que enrutan cada hostname al container Traefik

### Paso 5 — Obtener tunnel token y meterlo al .env

```bash
terraform output -raw tunnel_token
```

Copia el token y pégalo en `.env`:
```
CLOUDFLARE_TUNNEL_TOKEN=eyJh...muchas-letras
```

### Paso 6 — Levantar cloudflared

Cuando hagas `podman-compose up -d`, el container `cloudflared` lee el token del `.env` y se conecta automáticamente.

Verificar:
```bash
podman logs cloudflared
```

Debes ver:
```
INF Connection registered connIndex=0 location=...
```

## Verificar que funciona

```bash
# Desde tu Mac
curl -I https://home.tudominio.com

# Debe devolver headers de Cloudflare:
# server: cloudflare
# cf-ray: ...
```

Abre en navegador → debe cargar Homepage.

## Troubleshooting

### "DNS_PROBE_FINISHED_NXDOMAIN"
- Los CNAMEs tardan ~1 min en propagarse.
- Verifica: `dig home.tudominio.com CNAME`
- Debe responder algo como `<tunnel-id>.cfargotunnel.com`

### "Error 502 Bad Gateway"
- cloudflared está conectado pero Traefik no responde.
- `podman logs traefik` → ¿está corriendo?
- `podman exec cloudflared wget -O- http://traefik:80` → ¿conecta?

### "Error 530"
- Significa que cloudflared no está conectado.
- `podman logs cloudflared` → revisa el token
- Verifica en Cloudflare dashboard → Zero Trust → Networks → Tunnels: debe aparecer "Healthy"

### Servicio nuevo, ¿cómo agregarlo?

1. En `terraform/cloudflare/variables.tf`, agrega entrada en `services`:
   ```hcl
   "nuevoservicio" = "http://traefik:80"
   ```
2. `terraform apply`
3. En `docker-compose.yml`, agrega labels al container:
   ```yaml
   labels:
     - "traefik.enable=true"
     - "traefik.http.routers.nuevo.rule=Host(`nuevoservicio.${DOMAIN}`)"
     - "traefik.http.routers.nuevo.entrypoints=web"
     - "traefik.http.services.nuevo.loadbalancer.server.port=PUERTO"
   ```
4. `podman-compose up -d nuevoservicio`

## Plan free vs paid

El plan free de Cloudflare es generoso:
- Unlimited bandwidth
- DDoS protection
- SSL gratis
- 50 tunnels por cuenta
- Workers, R2, etc.

Para tu caso personal NO necesitas plan paid.
