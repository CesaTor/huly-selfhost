#!/bin/bash

if [ -f ".env" ]; then
    source ".env"
fi

if [ -f "huly_v7.conf" ]; then
    source "huly_v7.conf"
fi

RECREATE=false
if [ "$1" == "--recreate" ]; then
    RECREATE=true
fi

if [ "$RECREATE" == true ]; then
    cp .template.Caddyfile Caddyfile
    echo "Caddyfile has been recreated from the template."
else
    if [ ! -f "Caddyfile" ]; then
        echo "Caddyfile not found, creating from template."
        cp .template.Caddyfile Caddyfile
    else
        echo "Caddyfile already exists. Only updating port."
        echo "Run with --recreate to fully overwrite Caddyfile."
    fi
fi

# No port substitution needed — container always listens on port 80.
# HTTP_PORT in compose.yml controls the host port mapping only.

echo -e "\033[1;32mCaddyfile generated successfully.\033[0m"

read -p "Do you want to run 'docker compose restart caddy' now? (Y/n): " RUN_CADDY
case "${RUN_CADDY:-Y}" in
    [Yy]* )
        echo -e "\033[1;32mRunning 'docker compose restart caddy' now...\033[0m"
        docker compose restart caddy
        ;;
    [Nn]* )
        echo "You can run 'docker compose restart caddy' later to load your updated config."
        ;;
esac
