#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="huly_v7.conf"
MODE="quick"

for arg in "$@"; do
    case "$arg" in
        --interactive) MODE="interactive" ;;
        --secret) MODE="secret" ;;
        --help|-h)
            echo "Usage: ./setup.sh [--interactive|--secret]"
            echo ""
            echo "  (default)       Quick setup with sane defaults, preserves existing values"
            echo "  --interactive   Prompt for all settings"
            echo "  --secret        Regenerate secrets only"
            exit 0 ;;
        *) echo "Unknown option: $arg"; exit 1 ;;
    esac
done

# ── Helpers ────────────────────────────────────────────────────────────────────
generate_secret() {
    local file="$1"
    [ -f "$file" ] && return 0   # ponytail: never overwrite existing secrets
    openssl rand -hex 32 > "$file"
}

# ── Secrets ────────────────────────────────────────────────────────────────────
mkdir -p .secrets
generate_secret .secrets/huly.secret
generate_secret .secrets/pg.secret
generate_secret .secrets/redpanda.secret

if [ "$MODE" = "secret" ]; then
    echo -e "\033[1;32mSecrets regenerated in .secrets/\033[0m"
    echo "Re-run ./setup.sh to regenerate config."
    exit 0
fi

# ── Load existing config for defaults ──────────────────────────────────────────
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

# ── Set values: preserve existing, fall back to defaults ───────────────────────
if [ "$MODE" = "interactive" ]; then
    echo -e "\033[1;34mHuly Self-Hosted Setup\033[0m"
    echo ""

    read -p "Host address [${HOST_ADDRESS:-localhost:8080}]: " input
    _HOST_ADDRESS="${input:-${HOST_ADDRESS:-localhost:8080}}"

    read -p "HTTP port [${HTTP_PORT:-8080}]: " input
    _HTTP_PORT="${input:-${HTTP_PORT:-8080}}"

    read -p "Bind address, empty=all interfaces [${HTTP_BIND:-}]: " input
    _HTTP_BIND="${input:-${HTTP_BIND:-}}"

    read -p "Enable SSL? (y/N): " input
    _SECURE=$(echo "${input:-n}" | grep -qi y && echo "true" || echo "")

    read -p "Site title [${TITLE:-Huly}]: " input
    _TITLE="${input:-${TITLE:-Huly}}"

    read -p "Docker project name [${DOCKER_NAME:-huly}]: " input
    _DOCKER_NAME="${input:-${DOCKER_NAME:-huly}}"

    read -p "PostgreSQL user [${PG_USER:-selfhost}]: " input
    _PG_USER="${input:-${PG_USER:-selfhost}}"

    read -p "PostgreSQL database [${PG_DATABASE:-huly}]: " input
    _PG_DATABASE="${input:-${PG_DATABASE:-huly}}"

    read -p "PostgreSQL volume path [${VOLUME_PG_DATA:-Docker named volume}]: " input
    _VOLUME_PG_DATA="${input:-${VOLUME_PG_DATA:-}}"

    read -p "Elasticsearch volume path [${VOLUME_ELASTIC_PATH:-Docker named volume}]: " input
    _VOLUME_ELASTIC_PATH="${input:-${VOLUME_ELASTIC_PATH:-}}"

    read -p "Files volume path [${VOLUME_FILES_PATH:-Docker named volume}]: " input
    _VOLUME_FILES_PATH="${input:-${VOLUME_FILES_PATH:-}}"

    read -p "Redpanda volume path [${VOLUME_REDPANDA_PATH:-Docker named volume}]: " input
    _VOLUME_REDPANDA_PATH="${input:-${VOLUME_REDPANDA_PATH:-}}"

    _DEFAULT_LANGUAGE="${DEFAULT_LANGUAGE:-en}"
    _LAST_NAME_FIRST="${LAST_NAME_FIRST:-true}"
    _REDPANDA_ADMIN_USER="${REDPANDA_ADMIN_USER:-superadmin}"
else
    # Quick mode — preserve existing values, default only if unset
    _HOST_ADDRESS="${HOST_ADDRESS:-localhost:8080}"
    _HTTP_PORT="${HTTP_PORT:-8080}"
    _HTTP_BIND="${HTTP_BIND:-}"
    _SECURE="${SECURE:-}"
    _TITLE="${TITLE:-Huly}"
    _DEFAULT_LANGUAGE="${DEFAULT_LANGUAGE:-en}"
    _LAST_NAME_FIRST="${LAST_NAME_FIRST:-true}"
    _DOCKER_NAME="${DOCKER_NAME:-huly}"
    _PG_USER="${PG_USER:-selfhost}"
    _PG_DATABASE="${PG_DATABASE:-huly}"
    _VOLUME_PG_DATA="${VOLUME_PG_DATA:-}"
    _VOLUME_ELASTIC_PATH="${VOLUME_ELASTIC_PATH:-}"
    _VOLUME_FILES_PATH="${VOLUME_FILES_PATH:-}"
    _VOLUME_REDPANDA_PATH="${VOLUME_REDPANDA_PATH:-}"
    _REDPANDA_ADMIN_USER="${REDPANDA_ADMIN_USER:-superadmin}"
fi

# ── Generate config from template ─────────────────────────────────────────────
export DOCKER_NAME=$_DOCKER_NAME
export HOST_ADDRESS=$_HOST_ADDRESS
export SECURE=$_SECURE
export HTTP_PORT=$_HTTP_PORT
export HTTP_BIND=$_HTTP_BIND
export TITLE=$_TITLE
export DEFAULT_LANGUAGE=$_DEFAULT_LANGUAGE
export LAST_NAME_FIRST=$_LAST_NAME_FIRST
export PG_USER=$_PG_USER
export PG_DATABASE=$_PG_DATABASE
export VOLUME_PG_DATA=$_VOLUME_PG_DATA
export VOLUME_ELASTIC_PATH=$_VOLUME_ELASTIC_PATH
export VOLUME_FILES_PATH=$_VOLUME_FILES_PATH
export VOLUME_REDPANDA_PATH=$_VOLUME_REDPANDA_PATH
export REDPANDA_ADMIN_USER=$_REDPANDA_ADMIN_USER
export HULY_SECRET=$(cat .secrets/huly.secret)
export PG_SECRET=$(cat .secrets/pg.secret)
export REDPANDA_SECRET=$(cat .secrets/redpanda.secret)
export MAIL_SOURCE="${MAIL_SOURCE:-noreply@example.com}"
export SMTP_HOST="${SMTP_HOST:-}"
export SMTP_PORT="${SMTP_PORT:-587}"
export SMTP_USERNAME="${SMTP_USERNAME:-}"
export SMTP_PASSWORD="${SMTP_PASSWORD:-}"

envsubst < .template.huly.conf > "$CONFIG_FILE"

# Recreate .env symlink for docker compose
rm -f .env
ln -sf "$CONFIG_FILE" .env

# ── Generate Caddyfile ────────────────────────────────────────────────────────
if [ -f .template.Caddyfile ]; then
    cp .template.Caddyfile Caddyfile
    echo "  Generated Caddyfile"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "\033[1;34mConfiguration Summary:\033[0m"
echo -e "  Host:          \033[1;32m$_HOST_ADDRESS\033[0m"
echo -e "  HTTP Port:     \033[1;32m$_HTTP_PORT\033[0m"
echo -e "  SSL:           \033[1;32m${_SECURE:-no}\033[0m"
echo -e "  PostgreSQL:    \033[1;32m${_PG_USER}@postgres:5432/${_PG_DATABASE}\033[0m"
echo -e "  Docker name:   \033[1;32m$_DOCKER_NAME\033[0m"
echo ""
echo -e "\033[1;32mSetup complete!\033[0m"

# ── Start containers ──────────────────────────────────────────────────────────
if [ "$MODE" = "interactive" ]; then
    read -p "Run 'docker compose up -d' now? (Y/n): " run_docker
    case "${run_docker:-Y}" in
        [Yy]*) docker compose up -d ;;
    esac
else
    echo "Starting containers..."
    docker compose up -d
fi
