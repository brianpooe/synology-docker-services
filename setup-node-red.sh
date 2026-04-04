#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APPDATA="$PARENT_DIR/appdata"
STACK_DIR="$SCRIPT_DIR/docker-compose-files/node-red"
ENV_FILE="$SCRIPT_DIR/.env"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Parse a single value from the .env file safely (no sourcing)
get_env_value() {
  local key="$1"
  local line value
  line=$(grep -E "^${key}=" "$ENV_FILE" 2>/dev/null | head -1) || true
  value="${line#*=}"
  if [[ "$value" =~ ^\"(.*)\"[[:space:]]*(#.*)?$ ]]; then
    value="${BASH_REMATCH[1]}"
  elif [[ "$value" =~ ^\'(.*)\'[[:space:]]*(#.*)?$ ]]; then
    value="${BASH_REMATCH[1]}"
  fi
  printf '%s' "$value"
}

echo "==> Checking required .env variables"
REQUIRED_VARS=(TZ HA_TOKEN DOCKERLOGGING_MAXFILE DOCKERLOGGING_MAXSIZE)
MISSING=()
for var in "${REQUIRED_VARS[@]}"; do
  if [[ -z "$(get_env_value "$var")" ]]; then
    MISSING+=("$var")
  fi
done
if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "Error: missing required variables in .env:"
  for var in "${MISSING[@]}"; do echo "  - $var"; done
  exit 1
fi

# Auto-generate NODE_RED_CREDENTIAL_SECRET if not already in .env
if [[ -z "$(get_env_value "NODE_RED_CREDENTIAL_SECRET")" ]]; then
  echo "==> Generating NODE_RED_CREDENTIAL_SECRET and saving to .env"
  SECRET="$(openssl rand -hex 32)"
  printf '\nNODE_RED_CREDENTIAL_SECRET="%s"\n' "$SECRET" >> "$ENV_FILE"
  echo "    Generated: $SECRET"
fi

# Build a minimal .env containing only the variables each template needs.
write_minimal_env() {
  local tmp_env="$1"; shift
  : > "$tmp_env"
  for var in "$@"; do
    local val
    val=$(get_env_value "$var")
    printf '%s="%s"\n' "$var" "$val" >> "$tmp_env"
  done
}

echo "==> Creating appdata directory at $APPDATA/node-red"
sudo mkdir -p "$APPDATA/node-red"
# Node-RED container runs as uid 1000 — it must own /data to write flows and credentials
sudo chown -R 1000:1000 "$APPDATA/node-red"

echo "==> Substituting settings.js"
write_minimal_env "$TMP_DIR/env.settings" NODE_RED_CREDENTIAL_SECRET
"$SCRIPT_DIR/substitute_env.sh" \
  "$STACK_DIR/config/settings.js" \
  "$TMP_DIR/settings.js" \
  "$TMP_DIR/env.settings"
sudo cp "$TMP_DIR/settings.js" "$APPDATA/node-red/settings.js"

echo "==> Generating docker-compose.node-red.yml"
write_minimal_env "$TMP_DIR/env.compose" TZ HA_URL HA_TOKEN DOCKERLOGGING_MAXFILE DOCKERLOGGING_MAXSIZE
"$SCRIPT_DIR/substitute_env.sh" \
  "$STACK_DIR/template.yaml" \
  "$PARENT_DIR/docker-compose.node-red.yml" \
  "$TMP_DIR/env.compose"

echo ""
echo "Done. Next steps:"
echo "  1. Build the image:  docker compose -f $PARENT_DIR/docker-compose.node-red.yml build"
echo "  2. Start:            docker compose -f $PARENT_DIR/docker-compose.node-red.yml up -d"
echo "  3. Open http://<host>:1880 and add the Home Assistant server node"
echo "     URL:   http://homeassistant:8123"
echo "     Token: a Long-Lived Access Token from your HA profile page"
