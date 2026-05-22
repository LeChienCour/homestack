# 01 — Setup de Podman en Mac mini

## ¿Qué es Podman?

Podman es como Docker pero sin el "daemon" centralizado. En Mac corre dentro de una VM Linux mínima llamada **Podman Machine**. Es ligero (~500MB de RAM) y compatible con todos los comandos de Docker.

## Instalación

```bash
# Si no tienes Homebrew:
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Instalar Podman + tooling
brew install podman podman-compose
```

## Inicializar Podman Machine

```bash
# Crear la VM con recursos adecuados para tu Mac mini de 16GB
podman machine init \
  --cpus 4 \
  --memory 8192 \
  --disk-size 80

# Arrancar
podman machine start

# Verificar
podman info
podman version
```

**Importante:** los 8GB de la VM compiten con macOS. Si notas tu Mac lento, puedes bajar a 6GB:
```bash
podman machine stop
podman machine set --memory 6144
podman machine start
```

## Configurar arranque automático

Para que Podman Machine arranque sola al encender el Mac mini:

```bash
# Crear LaunchAgent
mkdir -p ~/Library/LaunchAgents
cat > ~/Library/LaunchAgents/com.diego.podman.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.diego.podman</string>
    <key>ProgramArguments</key>
    <array>
        <string>/opt/homebrew/bin/podman</string>
        <string>machine</string>
        <string>start</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/podman.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/podman.err</string>
</dict>
</plist>
EOF

launchctl load ~/Library/LaunchAgents/com.diego.podman.plist
```

## Configurar Mac mini como servidor

```bash
# No dormir nunca, encender tras corte de luz, despertar por red
sudo pmset -a sleep 0 disablesleep 1 womp 1 autorestart 1

# Verificar
pmset -g
```

## Compatibilidad con Docker

Podman expone la misma API que Docker. Si una herramienta espera Docker:

```bash
# Crear alias permanente
echo 'alias docker=podman' >> ~/.zshrc

# Exponer socket Docker-compatible (para apps como Beszel que lo necesitan)
podman system service --time=0 unix:///tmp/podman.sock &
export DOCKER_HOST=unix:///tmp/podman.sock
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

Si todo está bien, deberías poder correr:

```bash
podman run --rm hello-world
```

Y ver `Hello from Docker!` (sí, dice Docker, es la imagen de prueba estándar).
