#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — Setup inicial del Homestack
# =============================================================================
# Ejecutar UNA SOLA VEZ después de clonar el repo en el Mac mini.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo "================================================================"
echo "  Homestack Bootstrap — Mac mini Apple Silicon"
echo "================================================================"
echo ""

# 1. Verificar Homebrew
if ! command -v brew &> /dev/null; then
  echo "❌ Homebrew no instalado. Instálalo desde https://brew.sh"
  exit 1
fi

# 2. Instalar tooling
echo "▶ Instalando herramientas (podman, terraform, sops, age, restic, cloudflared, ollama)..."
brew install podman podman-compose terraform sops age cloudflared restic jq ollama

# 2b. Iniciar Ollama nativo y descargar modelo ligero
echo "▶ Iniciando Ollama y descargando modelo llama3.2:3b..."
brew services start ollama
sleep 3
ollama pull llama3.2:3b || echo "  ⚠ Descarga el modelo manualmente luego: ollama pull llama3.2:3b"
launchctl setenv OLLAMA_KEEP_ALIVE 5m
launchctl setenv OLLAMA_FLASH_ATTENTION 1

# 3. Inicializar Podman Machine si no existe
if ! podman machine list --format "{{.Name}}" | grep -q "podman-machine-default"; then
  echo "▶ Creando Podman Machine..."
  podman machine init --cpus 4 --memory 8192 --disk-size 80
fi

if ! podman machine list --format "{{.Running}}" | grep -q "true"; then
  echo "▶ Iniciando Podman Machine..."
  podman machine start
fi

# 4. Configurar macOS para uso server
echo "▶ Configurando Mac mini para uso server (no dormir)..."
echo "  (Pide tu contraseña)"
sudo pmset -a sleep 0 disablesleep 1 womp 1 autorestart 1

# 5. Verificar disco USB de backups
BACKUP_DISK="/Volumes/HomestackBackups"
if [[ ! -d "$BACKUP_DISK" ]]; then
  echo "⚠️  Disco USB no montado en $BACKUP_DISK"
  echo "   Conecta el disco, renómbralo a 'HomestackBackups' y vuelve a correr."
else
  echo "✓ Disco USB detectado en $BACKUP_DISK"
fi

# 6. Generar claves age para SOPS si no existen
SOPS_AGE_DIR="$HOME/.config/sops/age"
SOPS_AGE_KEY="$SOPS_AGE_DIR/keys.txt"
if [[ ! -f "$SOPS_AGE_KEY" ]]; then
  echo "▶ Generando llave age para SOPS..."
  mkdir -p "$SOPS_AGE_DIR"
  age-keygen -o "$SOPS_AGE_KEY"
  chmod 600 "$SOPS_AGE_KEY"
  PUBLIC_KEY=$(grep "public key" "$SOPS_AGE_KEY" | awk '{print $NF}')
  echo ""
  echo "✓ Tu clave pública age es:"
  echo "  $PUBLIC_KEY"
  echo ""
  echo "  Edita .sops.yaml y reemplaza 'age1tu-clave-publica-aqui' con la anterior."
else
  echo "✓ Llave SOPS ya existe en $SOPS_AGE_KEY"
fi

# 7. Crear .env desde .env.example si no existe
if [[ ! -f "$REPO_DIR/.env" ]]; then
  cp "$REPO_DIR/.env.example" "$REPO_DIR/.env"
  echo "▶ Creado .env desde plantilla. EDÍTALO antes de continuar."
fi

# 8. Generar passwords aleatorios si están en blanco
echo ""
echo "▶ Sugerencia de passwords aleatorios (cópialos a .env si los necesitas):"
echo ""
echo "  POSTGRES_PASSWORD=$(openssl rand -base64 24)"
echo "  REDIS_PASSWORD=$(openssl rand -base64 24)"
echo "  N8N_ENCRYPTION_KEY=$(openssl rand -hex 32)"
echo "  N8N_USER_MANAGEMENT_JWT_SECRET=$(openssl rand -hex 32)"
echo "  DOCUSEAL_SECRET_KEY_BASE=$(openssl rand -hex 64)"
echo "  POSTIZ_JWT_SECRET=$(openssl rand -hex 32)"
echo "  VAULTWARDEN_ADMIN_TOKEN=$(openssl rand -base64 48)"
echo "  UMAMI_APP_SECRET=$(openssl rand -hex 32)"
echo "  VIKUNJA_JWT_SECRET=$(openssl rand -hex 32)"
echo "  RESTIC_PASSWORD=$(openssl rand -base64 32)"
echo ""

echo "================================================================"
echo "  Siguientes pasos:"
echo "================================================================"
echo "  1. Edita .env con tus valores (dominio, passwords, AWS creds)"
echo "  2. Configura AWS CLI:    aws configure --profile homestack"
echo "  3. cd terraform/aws && terraform init && terraform apply"
echo "  4. cd ../cloudflare && terraform init && terraform apply"
echo "  5. Copia tunnel_token del output a .env"
echo "  6. cd ../../compose && podman-compose up -d"
echo "  7. Verifica:    podman ps"
echo "================================================================"
