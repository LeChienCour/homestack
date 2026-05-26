# 01 — Setup de Podman en Mac mini

## ¿Qué es Podman?

Podman es como Docker pero sin el "daemon" centralizado. En Mac corre dentro de una VM Linux mínima llamada **Podman Machine**. Es ligero (~500MB de RAM) y compatible con todos los comandos de Docker.

## Instalación

```bash
brew install podman podman-compose vfkit
```

> ⚠️ **`vfkit` es obligatorio** para el Apple Hypervisor que usa Podman en Apple Silicon. Sin él la VM no arranca.

## Inicializar Podman Machine

El repo vive en `/Volumes/Dock`. La VM **no tiene acceso a volumes externos** por defecto — el flag `--volume` solo funciona en `machine init`, no después.

```bash
# Crear la VM con acceso a /Volumes/Dock
podman machine init \
  --cpus 5 \
  --memory 6144 \
  --disk-size 30 \
  --volume /Volumes/Dock:/Volumes/Dock

# Arrancar
podman machine start

# Verificar
podman info
podman version
```

> ⚠️ Si ya tienes una VM sin el `--volume`, debes recrearla:
> ```bash
> podman machine stop
> podman machine rm podman-machine-default
> # luego re-ejecutar el init de arriba
> ```

**Nota de recursos:** 6 GB RAM para la VM. macOS + Ollama nativo usan el resto de los 16 GB. No subir la VM a más de 8 GB.

## Socket rootless

El socket de Podman en modo rootless está en:
```
/run/user/501/podman/podman.sock
```

Los containers que necesitan el socket (Traefik, Dozzle, Beszel agent) lo montan como:
```yaml
volumes:
  - /run/user/501/podman/podman.sock:/var/run/docker.sock:ro
security_opt:
  - label=disable   # necesario para SELinux dentro de la VM
```

> **No usar** `/var/run/docker.sock` ni `/tmp/podman.sock` — esas rutas no existen en rootless.

## Configurar arranque automático

Podman Machine no arranca sola al reiniciar el Mac. Instalar el Launch Agent incluido en el repo:

```bash
# Instala el plist en ~/Library/LaunchAgents y lo activa
bash scripts/install-podman-autostart.sh
```

El script `scripts/start-podman-machine.sh` espera hasta 60 segundos a que `/Volumes/Dock` esté montado antes de iniciar la VM (importante si el disco USB demora en montarse).

Verificar que está activo:
```bash
launchctl list | grep homestack
# debe aparecer com.homestack.podman-machine
```

## Configurar Mac mini como servidor

```bash
# No dormir nunca, encender tras corte de luz, despertar por red
sudo pmset -a sleep 0 disablesleep 1 womp 1 autorestart 1

# Verificar
pmset -g
```

## Comandos básicos

```bash
podman ps                    # Containers corriendo
podman ps -a                 # Todos (incluye detenidos)
podman logs <container>      # Ver logs
podman exec -it <c> sh       # Entrar al container
podman volume ls             # Ver volumes
podman system df             # Ver uso de disco
podman system prune          # Limpiar basura
```

## Verificación final

```bash
podman run --rm hello-world
```

Debe mostrar `Hello from Docker!`.

## Troubleshooting rápido

| Error | Causa | Fix |
|---|---|---|
| `vfkit: command not found` | vfkit no instalado | `brew install vfkit` |
| `statfs /private/var/run/docker.sock: no such file or directory` | Socket path incorrecto | Usar `/run/user/501/podman/podman.sock` |
| `statfs /Volumes/Dock: no such file or directory` | Volumen no compartido con VM | Recrear VM con `--volume /Volumes/Dock:/Volumes/Dock` |
| `permission denied` al leer socket | SELinux bloquea | Agregar `security_opt: [label=disable]` |
| SSH timeout al `machine start` | vfkit no está / VM tardó | Esperar 30s, reintentar `machine start` |
