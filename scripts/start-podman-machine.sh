#!/bin/bash
# =============================================================================
# start-podman-machine.sh
# Arranca Podman Machine al login. Espera a que /Volumes/Dock esté montado
# antes de intentar iniciar (el disco de la VM vive ahí).
# Instalado como Launch Agent — ver scripts/install-podman-autostart.sh
# =============================================================================

MACHINE_NAME="podman-machine-default"
PODMAN="/opt/homebrew/bin/podman"
DOCK_VOLUME="/Volumes/Dock"
MAX_WAIT=60  # segundos máximos esperando el volumen

# Esperar a que el volumen Dock esté montado
elapsed=0
while [ ! -d "$DOCK_VOLUME" ]; do
    if [ $elapsed -ge $MAX_WAIT ]; then
        echo "$(date): Timeout esperando $DOCK_VOLUME — abortando" >&2
        exit 1
    fi
    sleep 2
    elapsed=$((elapsed + 2))
done

echo "$(date): $DOCK_VOLUME disponible, arrancando $MACHINE_NAME..."

# Si ya está corriendo no hacer nada
if "$PODMAN" machine inspect "$MACHINE_NAME" --format '{{.State}}' 2>/dev/null | grep -q "running"; then
    echo "$(date): $MACHINE_NAME ya está running"
    exit 0
fi

"$PODMAN" machine start "$MACHINE_NAME"
echo "$(date): $MACHINE_NAME iniciado (exit $?)"
