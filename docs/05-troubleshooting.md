# 05 — Troubleshooting

## Podman Machine / arranque

### `vfkit: command not found` al iniciar VM

```bash
brew install vfkit
podman machine start
```

### SSH timeout al `podman machine start`

La VM puede tardar 20-30 segundos. El mensaje `did not transition to running` es falso si después:
```bash
podman machine inspect podman-machine-default --format '{{.State}}'
# running  ← ya está, ignorar el mensaje anterior
```

### `statfs /private/var/run/docker.sock: no such file or directory`

Socket incorrecto. En rootless Podman el path correcto es:
```
/run/user/501/podman/podman.sock
```
Verificar que `docker-compose.yml` use ese path en traefik, dozzle, beszel-agent.

### `statfs /Volumes/Dock: no such file or directory`

La VM no tiene acceso a `/Volumes/Dock`. El flag `--volume` solo funciona en `machine init`:

```bash
podman machine stop
podman machine rm podman-machine-default
podman machine init \
  --cpus 5 --memory 6144 --disk-size 30 \
  --volume /Volumes/Dock:/Volumes/Dock
podman machine start
```

### Container no puede leer el socket (permission denied)

SELinux dentro de la VM bloquea el acceso. Agregar a cada container que usa el socket:
```yaml
security_opt:
  - label=disable
```
Necesario en: `traefik`, `dozzle`, `beszel-agent`.

---

## Container no arranca

```bash
# Ver el error real
podman logs <nombre-container>

# Ver detalles del crash
podman inspect <nombre-container> | grep -A 5 State

# Probar levantar solo (sin -d) para ver logs en vivo
cd compose
podman-compose up <servicio>
```

## "No space left on device"

Podman Machine tiene 30 GB de disco.

```bash
# Limpiar containers detenidos, imágenes huérfanas, etc.
podman system prune -a --volumes

# Ver uso
podman system df

# Si todavía falta, aumentar disco (requiere recrear VM):
podman machine stop
podman machine rm podman-machine-default
podman machine init --cpus 5 --memory 6144 --disk-size 60 \
  --volume /Volumes/Dock:/Volumes/Dock
```

---

## Cloudflare Tunnel

### "Provided Tunnel token is not valid"

Pegaste el **Tunnel ID** (UUID de 36 chars) en vez del **Tunnel Token** (base64 ~180 chars).

Token correcto se obtiene en:
- Zero Trust → Networks → Tunnels → tu tunnel → Configure → token (la cadena larga base64)

```bash
# Actualizar .env, luego:
podman-compose up -d --force-recreate cloudflared
podman logs cloudflared | grep -v precheck
# Debe mostrar: INF Registered tunnel connection connIndex=0
```

### cloudflared conectado pero todos los hostnames dan 404

El tunnel está up pero sin reglas de ingress. Agregar en Cloudflare Zero Trust:
- Tunnels → tu tunnel → Public Hostname → agregar cada subdominio apuntando a `http://traefik:80`

### "DNS_PROBE_FINISHED_NXDOMAIN"

Los CNAMEs tardan ~1 min en propagarse.
```bash
dig home.tudominio.com CNAME
# debe responder <tunnel-id>.cfargotunnel.com
```

### "Error 502 Bad Gateway"
cloudflared conectado, Traefik no responde.
```bash
podman logs traefik
```

### "Error 530"
cloudflared no conectado. Verificar token y logs.

---

## Terraform

### `Error: No valid credential sources found`

Perfil AWS no existe o no está configurado:
```bash
aws configure list-profiles   # verificar que existe "admin"
aws configure --profile admin
```

### Backend requires init

Después de cambiar el backend:
```bash
cd terraform/cloudflare  # o terraform/aws
terraform init -reconfigure
```

### `TF_VAR_domain not set`

Las variables sensibles se pasan como env vars, no en tfvars:
```bash
export TF_VAR_domain="tudominio.com"
export TF_VAR_cloudflare_api_token="..."
export TF_VAR_cloudflare_account_id="..."
export TF_VAR_tunnel_id="<UUID-del-tunnel>"
make tf-cf-apply
```

---

## Postgres no acepta conexiones

```bash
# Verificar que esté healthy
podman ps | grep postgres

# Probar conexión desde otro container
podman exec n8n nc -zv postgres 5432

# Conectarte manualmente
podman exec -it postgres psql -U ${POSTGRES_USER}
```

## Listmonk no envía emails

```bash
podman logs listmonk --tail 100
# Errores comunes:
# - "EOF" o "connection refused" → credenciales SES malas
# - "554 Message rejected" → en SES sandbox, recipient no verificado
# - "421 Throttling" → bajar "Max conns" a 5
```

Test manual:
```bash
podman exec -it listmonk sh
nc -zv email-smtp.us-east-1.amazonaws.com 587
# debe responder "succeeded"
```

## Backups fallan

```bash
# Ver el último log
cat ~/Library/Logs/homestack/backup.error.log

# Probar manualmente
./scripts/backup.sh

# Errores comunes:
# - "repository does not exist" → disco USB desmontado
# - "wrong password" → RESTIC_PASSWORD cambió, NO se puede recuperar
```

⚠️ **CRÍTICO**: si pierdes `RESTIC_PASSWORD`, todos los backups quedan inaccesibles. Guárdala en Vaultwarden.

## Mac mini sleep / pierdo conexión nocturna

```bash
pmset -g | grep -E "sleep|hibernate|disksleep"
# Debe mostrar sleep 0

# Re-aplicar si algo cambió:
sudo pmset -a sleep 0 disablesleep 1 womp 1 autorestart 1
```

## Subdominio nuevo da 404

Tres puntos a verificar en orden:

1. **DNS propagado?**
   ```bash
   dig nuevoservicio.tudominio.com CNAME
   # debe responder <tunnel-id>.cfargotunnel.com
   ```

2. **Ingress rule en Cloudflare Tunnel?**
   - Zero Trust → Tunnels → Public Hostnames → ¿aparece el subdominio?

3. **Label Traefik en el container?**
   ```bash
   podman inspect <container> | grep traefik
   ```

## Cómo reiniciar todo limpio

```bash
cd compose
podman-compose down
podman-compose up -d
```

## Stack quema demasiada RAM

```bash
# Ver consumo por container
podman stats --no-stream

# Detener apps que no uses ahora
podman-compose stop postiz  # ejemplo
```

## Cómo ver lo que está pasando en tiempo real

- **Logs**: `https://logs.tudominio.com` (Dozzle)
- **Métricas**: `https://metrics.tudominio.com` (Beszel)
- **CLI**: `podman stats` o `podman logs -f <container>`
