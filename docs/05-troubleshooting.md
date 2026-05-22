# 05 — Troubleshooting

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

Podman Machine tiene disco limitado (lo configuraste en 80GB).

```bash
# Limpiar containers detenidos, imágenes huérfanas, etc.
podman system prune -a --volumes

# Ver uso
podman system df

# Si todavía falta, aumentar disco:
podman machine stop
podman machine set --disk-size 120
podman machine start
```

## "Port already in use"

Otro proceso tiene el puerto. Solo Traefik debe escuchar en 80/443.

```bash
# Ver quién usa el puerto
sudo lsof -i :80

# Si es algo del Mac (Apache nativo), apagar:
sudo apachectl stop
sudo launchctl unload /System/Library/LaunchDaemons/org.apache.httpd.plist
```

## Cloudflare Tunnel "unhealthy"

```bash
# Logs detallados
podman logs cloudflared --tail 50

# Token incorrecto: regenera desde Terraform
cd terraform/cloudflare
terraform output -raw tunnel_token
# Actualiza .env y restart:
podman-compose restart cloudflared
```

## Postgres no acepta conexiones

```bash
# Verificar que esté healthy
podman ps | grep postgres

# Probar conexión desde otro container
podman exec n8n nc -zv postgres 5432

# Conectarte manualmente
podman exec -it postgres psql -U homestack
```

## Listmonk no envía emails

Síntomas: campañas se quedan en "running" sin avanzar.

```bash
# Logs Listmonk
podman logs listmonk --tail 100

# Errores comunes:
# - "EOF" o "connection refused" → SES credentials malas
# - "554 Message rejected" → estás en SES sandbox, recipient no verificado
# - "421 Throttling" → demasiados emails muy rápido, baja "Max conns" a 5
```

Test manual:
```bash
podman exec -it listmonk sh
# Dentro:
nc -zv email-smtp.us-east-1.amazonaws.com 587
# Debe responder "succeeded"
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
# Verificar config
pmset -g | grep -E "sleep|hibernate|disksleep"

# Debe mostrar:
# sleep        0
# disablesleep 1
# autorestart  1
```

Si dice algo diferente, vuelve a aplicar:
```bash
sudo pmset -a sleep 0 disablesleep 1 womp 1 autorestart 1
```

## Subdominio nuevo da 404

Tres puntos a verificar:

1. **DNS propagado?**
   ```bash
   dig nuevoservicio.tudominio.com CNAME
   # Debe responder <tunnel-id>.cfargotunnel.com
   ```

2. **Ingress rule en Cloudflare tunnel?**
   ```bash
   cd terraform/cloudflare
   terraform output service_urls
   # Debe listar el nuevo hostname
   ```

3. **Label Traefik en el container?**
   ```bash
   podman inspect <container> | grep traefik
   ```

## Cómo reiniciar todo limpio

```bash
cd compose
podman-compose down
podman-compose up -d

# Si quieres también limpiar imágenes viejas:
podman image prune
```

## Cómo reiniciar SIN perder datos

```bash
podman-compose restart  # mantiene volumes intactos
```

## Stack quema demasiada RAM

```bash
# Ver consumo por container
podman stats --no-stream

# Detener apps que no uses ahora
podman-compose stop postiz  # ejemplo

# Reducir memoria de Postgres (en docker-compose.yml):
# Agregar a postgres service:
#   command: -c "shared_buffers=128MB" -c "max_connections=50"
```

## Cómo ver lo que está pasando en tiempo real

- **Logs**: https://logs.tudominio.com (Dozzle)
- **Métricas**: https://metrics.tudominio.com (Beszel)
- **CLI**: `podman stats` o `podman logs -f <container>`
