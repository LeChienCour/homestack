#!/usr/bin/env bash
# =============================================================================
# restore.sh — Restaura un snapshot de Restic
# =============================================================================
# Uso: ./restore.sh <snapshot-id>
#      ./restore.sh latest

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

if [[ $# -lt 1 ]]; then
  echo "Uso: $0 <snapshot-id|latest>"
  echo ""
  echo "Para ver snapshots disponibles:"
  echo "  restic -r \$RESTIC_REPOSITORY snapshots"
  exit 1
fi

SNAPSHOT_ID="$1"

# Cargar variables
set -a
source "$REPO_DIR/.env"
set +a

export RESTIC_REPOSITORY RESTIC_PASSWORD

RESTORE_DIR=$(mktemp -d)
trap "rm -rf $RESTORE_DIR" EXIT

echo "⚠️  ATENCIÓN: Vas a restaurar el snapshot '$SNAPSHOT_ID'."
echo "   Esto detendrá todos los servicios y reemplazará los datos actuales."
read -p "¿Continuar? (escribe 'si' para confirmar): " CONFIRM
[[ "$CONFIRM" != "si" ]] && { echo "Cancelado."; exit 0; }

# 1. Restaurar archivos de Restic
echo "▶ Descargando snapshot..."
restic restore "$SNAPSHOT_ID" --target "$RESTORE_DIR"

# 2. Detener stack
echo "▶ Deteniendo stack..."
cd "$REPO_DIR/compose"
podman-compose down

# 3. Restaurar volumes
echo "▶ Restaurando volumes..."
for tarfile in "$RESTORE_DIR"/*/volumes/*.tar.gz; do
  [[ -f "$tarfile" ]] || continue
  vol=$(basename "$tarfile" .tar.gz)
  echo "  · $vol"
  podman volume rm "$vol" 2>/dev/null || true
  podman volume create "$vol"
  podman run --rm \
    -v "$vol:/target" \
    -v "$(dirname "$tarfile"):/backup:ro" \
    alpine tar xzf "/backup/$(basename "$tarfile")" -C /target
done

# 4. Levantar Postgres primero para restaurar el dump
echo "▶ Arrancando Postgres..."
podman-compose up -d postgres
sleep 10  # esperar a que esté listo

# 5. Restaurar dump SQL
SQL_DUMP=$(find "$RESTORE_DIR" -name "postgres-all.sql" -type f | head -1)
if [[ -f "$SQL_DUMP" ]]; then
  echo "▶ Restaurando dump SQL..."
  cat "$SQL_DUMP" | podman exec -i postgres psql -U "$POSTGRES_USER"
fi

# 6. Levantar resto del stack
echo "▶ Levantando stack completo..."
podman-compose up -d

echo ""
echo "✓ Restore completo."
podman ps
