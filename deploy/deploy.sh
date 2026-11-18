#!/usr/bin/env bash
# Pulls and restarts Bloom on the VM. CI runs it through a forced SSH command:
#
#   command="/home/ifkash/docs/apps/bloom/deploy.sh",restrict ssh-ed25519 AAAA... bloom-ci
#
# The first line of stdin is a GitHub token that can read ghcr.io packages.
# SSH_ORIGINAL_COMMAND is ignored, so the key can't run anything else.
set -euo pipefail

readonly APP_DIR=/home/ifkash/docs/apps/bloom
readonly REGISTRY=ghcr.io
readonly REGISTRY_USER=kashifulhaque

unset SSH_ORIGINAL_COMMAND
cd "$APP_DIR"

# Use a private Docker config for the registry login. The VM's own
# ~/.docker/config.json holds a ghcr.io login that other apps rely on; logging
# in and out there would replace it with this short-lived CI token and then
# delete it. Compose is a system-wide plugin, so it still works from here.
export DOCKER_CONFIG="$APP_DIR/.docker"
mkdir -p "$DOCKER_CONFIG"
chmod 700 "$DOCKER_CONFIG"

token=""
IFS= read -r token || true
if [[ -z "$token" ]]; then
  echo "deploy: no registry token on stdin" >&2
  exit 2
fi

# Always log out, even when a step fails, so the token isn't left on disk.
trap 'docker logout "$REGISTRY" >/dev/null 2>&1 || true' EXIT

printf '%s\n' "$token" | docker login "$REGISTRY" -u "$REGISTRY_USER" --password-stdin >/dev/null
unset token

docker compose pull --quiet
docker compose up -d --remove-orphans
docker logout "$REGISTRY" >/dev/null
docker image prune -f >/dev/null

echo "deploy: $(docker inspect -f '{{.Name}} {{.State.Status}} image={{.Image}}' bloom-web)"
docker compose ps --format 'table {{.Name}}\t{{.Status}}'
