# =============================================================================
# Homestack — Makefile
# =============================================================================
# Uso: make <target> [SVC=<servicio>] [CMD=<comando>]
# Requiere: podman-compose (o docker-compose como fallback)

COMPOSE_FILE := compose/docker-compose.yml
COMPOSE      := $(shell command -v podman-compose 2>/dev/null || echo "docker compose")
DC           := $(COMPOSE) -f $(COMPOSE_FILE)
TF_AWS       := terraform/aws
TF_CF        := terraform/cloudflare

# Colores
CYAN  := \033[0;36m
BOLD  := \033[1m
RESET := \033[0m

.DEFAULT_GOAL := help

# =============================================================================
# AYUDA
# =============================================================================

.PHONY: help
help: ## Muestra este menú
	@printf "$(BOLD)Homestack — comandos disponibles$(RESET)\n\n"
	@printf "$(CYAN)%-30s$(RESET) %s\n" "TARGET" "DESCRIPCIÓN"
	@printf "%-30s %s\n" "──────────────────────────────" "────────────────────────────────────────────"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "$(CYAN)%-30s$(RESET) %s\n", $$1, $$2}'

# =============================================================================
# STACK COMPLETO
# =============================================================================

.PHONY: up
up: env-check ## Levanta el stack completo en background
	$(DC) up -d

.PHONY: down
down: ## Para y elimina los containers (datos persistidos en volúmenes)
	$(DC) down

.PHONY: stop
stop: ## Para los containers sin eliminarlos
	$(DC) stop

.PHONY: restart
restart: ## Reinicia todos los containers
	$(DC) restart

.PHONY: pull
pull: ## Descarga las últimas imágenes sin reiniciar
	$(DC) pull

.PHONY: update
update: pull ## pull + recrear containers con nuevas imágenes
	$(DC) up -d --remove-orphans

.PHONY: recreate
recreate: ## Fuerza recreación de todos los containers (sin pull)
	$(DC) up -d --force-recreate

.PHONY: ps
ps: ## Estado de todos los containers
	$(DC) ps

.PHONY: status
status: ps ## Alias de ps

.PHONY: top
top: ## Uso de recursos por container (CPU/RAM)
	$(DC) top

# =============================================================================
# SERVICIO INDIVIDUAL  (usar SVC=nombre)
# =============================================================================

.PHONY: up-svc
up-svc: ## Levanta un servicio: make up-svc SVC=n8n
	@test -n "$(SVC)" || (echo "ERROR: Falta SVC=<servicio>"; exit 1)
	$(DC) up -d $(SVC)

.PHONY: stop-svc
stop-svc: ## Para un servicio: make stop-svc SVC=n8n
	@test -n "$(SVC)" || (echo "ERROR: Falta SVC=<servicio>"; exit 1)
	$(DC) stop $(SVC)

.PHONY: restart-svc
restart-svc: ## Reinicia un servicio: make restart-svc SVC=n8n
	@test -n "$(SVC)" || (echo "ERROR: Falta SVC=<servicio>"; exit 1)
	$(DC) restart $(SVC)

.PHONY: update-svc
update-svc: ## pull + recrear un servicio: make update-svc SVC=vikunja
	@test -n "$(SVC)" || (echo "ERROR: Falta SVC=<servicio>"; exit 1)
	$(DC) pull $(SVC)
	$(DC) up -d --no-deps $(SVC)

.PHONY: logs
logs: ## Logs en vivo (todos o SVC=nombre): make logs SVC=traefik
	$(DC) logs -f --tail=100 $(SVC)

.PHONY: exec
exec: ## Exec en container: make exec SVC=postgres CMD="psql -U postgres"
	@test -n "$(SVC)" || (echo "ERROR: Falta SVC=<servicio>"; exit 1)
	@test -n "$(CMD)" || (echo "ERROR: Falta CMD=<comando>"; exit 1)
	$(DC) exec $(SVC) $(CMD)

.PHONY: shell
shell: ## Shell bash/sh en container: make shell SVC=n8n
	@test -n "$(SVC)" || (echo "ERROR: Falta SVC=<servicio>"; exit 1)
	$(DC) exec $(SVC) sh -c "bash 2>/dev/null || sh"

# =============================================================================
# BASE DE DATOS
# =============================================================================

.PHONY: db-shell
db-shell: ## Shell psql en el postgres compartido
	$(DC) exec postgres psql -U $${POSTGRES_USER:-postgres} -d postgres

.PHONY: db-list
db-list: ## Lista todas las bases de datos
	$(DC) exec postgres psql -U $${POSTGRES_USER:-postgres} -c "\l"

.PHONY: db-shell-svc
db-shell-svc: ## psql en DB de un servicio: make db-shell-svc SVC=vikunja
	@test -n "$(SVC)" || (echo "ERROR: Falta SVC=<servicio>"; exit 1)
	$(DC) exec postgres psql -U $${POSTGRES_USER:-postgres} -d $(SVC)

.PHONY: db-dump
db-dump: ## Dump de TODAS las DBs: dump_<fecha>.sql en compose/postgres/
	@mkdir -p compose/postgres/dumps
	$(DC) exec -T postgres pg_dumpall -U $${POSTGRES_USER:-postgres} \
		> compose/postgres/dumps/dump_$$(date +%Y%m%d_%H%M%S).sql
	@echo "✓ Dump en compose/postgres/dumps/"

.PHONY: db-dump-svc
db-dump-svc: ## Dump de una DB: make db-dump-svc SVC=vikunja
	@test -n "$(SVC)" || (echo "ERROR: Falta SVC=<servicio>"; exit 1)
	@mkdir -p compose/postgres/dumps
	$(DC) exec -T postgres pg_dump -U $${POSTGRES_USER:-postgres} $(SVC) \
		> compose/postgres/dumps/$(SVC)_$$(date +%Y%m%d_%H%M%S).sql
	@echo "✓ Dump en compose/postgres/dumps/$(SVC)_*.sql"

# =============================================================================
# BACKUPS (Restic)
# =============================================================================

.PHONY: backup
backup: ## Corre backup manual con Restic (USB: HomestackBackups)
	bash scripts/backup.sh

.PHONY: backup-install-cron
backup-install-cron: ## Instala launchd para backup diario 3 AM
	bash scripts/install-backup-cron.sh

.PHONY: backup-snapshots
backup-snapshots: ## Lista snapshots Restic en disco USB
	@test -n "$$RESTIC_PASSWORD" || (echo "ERROR: export RESTIC_PASSWORD=<pass>"; exit 1)
	restic -r /Volumes/HomestackBackups/restic snapshots

.PHONY: restore
restore: ## Restaura desde backup: make restore SNAPSHOT=latest
	SNAPSHOT=$${SNAPSHOT:-latest} bash scripts/restore.sh

# =============================================================================
# TERRAFORM — Bootstrap (S3 state bucket — correr UNA SOLA VEZ)
# =============================================================================

.PHONY: tf-bootstrap
tf-bootstrap: ## Crea el S3 bucket para Terraform state (correr antes que todo)
	cd terraform/bootstrap && terraform init && terraform apply

# =============================================================================
# TERRAFORM — AWS (SES + IAM)
# =============================================================================

.PHONY: tf-aws-env
tf-aws-env: ## Muestra las variables de entorno necesarias para terraform/aws
	@printf "$(BOLD)Exporta antes de correr terraform/aws:$(RESET)\n"
	@printf "  export TF_VAR_domain=\"tudominio.com\"\n"
	@printf "\nVerifica que el AWS profile 'homestack' exista:\n"
	@printf "  aws configure list --profile homestack\n"

.PHONY: tf-aws-init
tf-aws-init: ## terraform init en terraform/aws
	cd $(TF_AWS) && terraform init

.PHONY: tf-aws-plan
tf-aws-plan: ## terraform plan en terraform/aws (requiere TF_VAR_domain)
	@test -n "$$TF_VAR_domain" || (printf "$(BOLD)ERROR:$(RESET) exporta TF_VAR_domain primero. Ver: make tf-aws-env\n" && exit 1)
	cd $(TF_AWS) && terraform plan

.PHONY: tf-aws-apply
tf-aws-apply: ## terraform apply en terraform/aws (requiere TF_VAR_domain)
	@test -n "$$TF_VAR_domain" || (printf "$(BOLD)ERROR:$(RESET) exporta TF_VAR_domain primero. Ver: make tf-aws-env\n" && exit 1)
	cd $(TF_AWS) && terraform apply

.PHONY: tf-aws-output
tf-aws-output: ## Muestra outputs de terraform/aws (SMTP creds, etc.)
	cd $(TF_AWS) && terraform output

.PHONY: tf-aws-destroy
tf-aws-destroy: ## ⚠️  terraform destroy en terraform/aws
	@printf "$(BOLD)ADVERTENCIA:$(RESET) Esto destruye SES + IAM en AWS.\n"
	@read -p "¿Confirmar? [y/N] " ans && [ "$$ans" = "y" ]
	cd $(TF_AWS) && terraform destroy

# =============================================================================
# TERRAFORM — Cloudflare (DNS records — tunnel pre-existente)
# =============================================================================

.PHONY: tf-cf-env
tf-cf-env: ## Muestra las variables de entorno necesarias para terraform/cloudflare
	@printf "$(BOLD)Exporta antes de correr terraform/cloudflare:$(RESET)\n"
	@printf "  export TF_VAR_domain=\"tudominio.com\"\n"
	@printf "  export TF_VAR_cloudflare_api_token=\"tu-token-cf\"\n"
	@printf "  export TF_VAR_cloudflare_account_id=\"tu-account-id\"\n"
	@printf "\nToken CF necesita permisos: Zone:DNS:Edit\n"
	@printf "Account ID: visible en la URL del dashboard de Cloudflare\n"

.PHONY: tf-cf-init
tf-cf-init: ## terraform init en terraform/cloudflare
	cd $(TF_CF) && terraform init

.PHONY: tf-cf-plan
tf-cf-plan: ## terraform plan en terraform/cloudflare (requiere TF_VAR_*)
	@test -n "$$TF_VAR_domain" || (printf "$(BOLD)ERROR:$(RESET) exporta variables primero. Ver: make tf-cf-env\n" && exit 1)
	@test -n "$$TF_VAR_cloudflare_api_token" || (printf "$(BOLD)ERROR:$(RESET) exporta TF_VAR_cloudflare_api_token. Ver: make tf-cf-env\n" && exit 1)
	cd $(TF_CF) && terraform plan

.PHONY: tf-cf-apply
tf-cf-apply: ## terraform apply en terraform/cloudflare (requiere TF_VAR_*)
	@test -n "$$TF_VAR_domain" || (printf "$(BOLD)ERROR:$(RESET) exporta variables primero. Ver: make tf-cf-env\n" && exit 1)
	@test -n "$$TF_VAR_cloudflare_api_token" || (printf "$(BOLD)ERROR:$(RESET) exporta TF_VAR_cloudflare_api_token. Ver: make tf-cf-env\n" && exit 1)
	cd $(TF_CF) && terraform apply

.PHONY: tf-cf-output
tf-cf-output: ## Muestra outputs de terraform/cloudflare
	cd $(TF_CF) && terraform output

.PHONY: tf-cf-destroy
tf-cf-destroy: ## ⚠️  terraform destroy en terraform/cloudflare (elimina DNS records)
	@printf "$(BOLD)ADVERTENCIA:$(RESET) Esto elimina todos los DNS records gestionados por TF.\n"
	@read -p "¿Confirmar? [y/N] " ans && [ "$$ans" = "y" ]
	cd $(TF_CF) && terraform destroy

# =============================================================================
# MCP VIKUNJA
# =============================================================================

.PHONY: mcp-install
mcp-install: ## Instala deps del MCP server (uv)
	cd mcp-vikunja && uv sync

.PHONY: mcp-run
mcp-run: ## Corre el MCP server en modo stdio (dev)
	cd mcp-vikunja && uv run python src/server.py

.PHONY: mcp-test
mcp-test: ## Corre tests del MCP server
	cd mcp-vikunja && uv run pytest -v 2>/dev/null || echo "Sin tests todavía"

# =============================================================================
# UTILIDADES
# =============================================================================

.PHONY: env-check
env-check: ## Verifica que exista .env con variables mínimas
	@test -f compose/.env || test -f .env || \
		(echo "ERROR: No se encontró .env. Copia .env.example → .env y llena los valores."; exit 1)
	@echo "✓ .env encontrado"

.PHONY: env-setup
env-setup: ## Copia .env.example → compose/.env si no existe
	@test -f compose/.env && echo "compose/.env ya existe" || \
		(cp .env.example compose/.env && echo "✓ compose/.env creado — edítalo con tus valores")

.PHONY: ses-smtp-password
ses-smtp-password: ## Genera el SMTP password de SES desde la secret key
	@test -n "$(AWS_SECRET_KEY)" || (echo "ERROR: Falta AWS_SECRET_KEY=<key>"; exit 1)
	AWS_SECRET_KEY=$(AWS_SECRET_KEY) bash scripts/ses-smtp-password.sh

.PHONY: bootstrap
bootstrap: ## Setup inicial completo (primera vez)
	bash scripts/bootstrap.sh

.PHONY: check-images-arm
check-images-arm: ## Verifica soporte ARM64 de imágenes críticas
	@echo "Verificando imágenes ARM64..."
	@for img in \
		"ghcr.io/gitroomhq/postiz-app:latest" \
		"vikunja/vikunja:latest" \
		"n8nio/n8n:latest" \
		"listmonk/listmonk:latest"; do \
		printf "%-50s " "$$img"; \
		docker manifest inspect "$$img" 2>/dev/null | \
			grep -q '"architecture": "arm64"' && echo "✓ arm64" || echo "✗ NO arm64"; \
	done

.PHONY: prune
prune: ## Limpia imágenes y volúmenes no usados (libera espacio)
	@read -p "¿Limpiar imágenes y volúmenes huérfanos? [y/N] " ans && [ "$$ans" = "y" ]
	$(COMPOSE) system prune -f
	$(COMPOSE) volume prune -f

.PHONY: gen-secrets
gen-secrets: ## Genera passwords seguros para el .env (openssl rand)
	@echo "# Pega estos valores en tu .env:"
	@echo "POSTGRES_PASSWORD=$$(openssl rand -hex 32)"
	@echo "REDIS_PASSWORD=$$(openssl rand -hex 24)"
	@echo "N8N_ENCRYPTION_KEY=$$(openssl rand -hex 32)"
	@echo "N8N_USER_MANAGEMENT_JWT_SECRET=$$(openssl rand -hex 32)"
	@echo "DOCUSEAL_SECRET_KEY_BASE=$$(openssl rand -hex 64)"
	@echo "LISTMONK_ADMIN_PASSWORD=$$(openssl rand -hex 16)"
	@echo "POSTIZ_JWT_SECRET=$$(openssl rand -hex 32)"
	@echo "UMAMI_APP_SECRET=$$(openssl rand -hex 32)"
	@echo "VIKUNJA_JWT_SECRET=$$(openssl rand -hex 32)"
	@echo "VAULTWARDEN_ADMIN_TOKEN=$$(openssl rand -base64 48)"
