#!/usr/bin/env bash
# =============================================================================
# backup.sh — Backup completo del Homestack a disco USB con Restic
# =============================================================================
# Hace dump de Postgres + snapshot de volumes Podman, encriptado con Restic.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Cargar variables de entorno
if [[ -f "$REPO_DIR/.env" ]]; then
  set -a
  source "$REPO_DIR/.env"
  set +a
else
  echo "❌ No se encontró .env"
  exit 1
fi

# Validar variables críticas
: "${RESTIC_REPOSITORY:?RESTIC_REPOSITORY no definido en .env}"
: "${RESTIC_PASSWORD:?RESTIC_PASSWORD no definido en .env}"
: "${POSTGRES_USER:?POSTGRES_USER no definido en .env}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD no definido en .env}"

export RESTIC_REPOSITORY RESTIC_PASSWORD

# Verificar que el disco esté montado
if [[ ! -d "$(dirname "$RESTIC_REPOSITORY")" ]]; then
  echo "❌ Disco de backup no montado: $(dirname "$RESTIC_REPOSITORY")"
  exit 1
fi

# Inicializar repo si no existe
if ! restic snapshots &> /dev/null; then
  echo "▶ Inicializando repositorio Restic en $RESTIC_REPOSITORY..."
  restic init
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

echo "================================================================"
echo "  Homestack Backup — $TIMESTAMP"
echo "================================================================"

# 1. Dump de Postgres (todas las DBs)
echo "▶ Haciendo dump de Postgres..."
podman exec postgres pg_dumpall -U "$POSTGRES_USER" > "$TMP_DIR/postgres-all.sql"
echo "  ✓ Dump: $(du -h "$TMP_DIR/postgres-all.sql" | cut -f1)"

# 2. Listar volumes a respaldar
VOLUMES=(
  "homestack_n8n_data"
  "homestack_listmonk_uploads"
  "homestack_docuseal_data"
  "homestack_postiz_uploads"
  "homestack_vaultwarden_data"
  "homestack_umami_data"
  "homestack_vikunja_files"
  "homestack_beszel_data"
  "homestack_traefik_data"
)

# 3. Exportar cada volume como tar
echo "▶ Exportando volumes Podman..."
mkdir -p "$TMP_DIR/volumes"
for vol in "${VOLUMES[@]}"; do
  if podman volume exists "$vol"; then
    echo "  · $vol"
    podman run --rm \
      -v "$vol:/source:ro" \
      -v "$TMP_DIR/volumes:/backup" \
      alpine tar czf "/backup/${vol}.tar.gz" -C /source . 2>/dev/null
  else
    echo "  ⚠ $vol no existe, skip"
  fi
done

# 4. Backup con Restic
echo "▶ Subiendo a Restic..."
restic backup \
  --tag "auto-$TIMESTAMP" \
  --tag "homestack" \
  "$TMP_DIR"

# 5. Aplicar política de retención
echo "▶ Aplicando retención (7 diarios, 4 semanales, 12 mensuales)..."
restic forget \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 12 \
  --prune

# 6. Verificar integridad (solo 5% de los datos para que sea rápido)
echo "▶ Verificando integridad..."
restic check --read-data-subset=5%

echo ""
echo "✓ Backup completo. Snapshots actuales:"
restic snapshots --compact

echo ""
echo "================================================================"
echo "  Backup terminado: $(date)"
echo "================================================================"
