#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APPDATA="$PARENT_DIR/appdata"
STACK_DIR="$SCRIPT_DIR/docker-compose-files/homeassistant"
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
REQUIRED_VARS=(TZ SLZB06_HOST DOCKERLOGGING_MAXFILE DOCKERLOGGING_MAXSIZE)
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

# Build a minimal .env containing only the variables each template needs.
# This avoids passing large/complex values (e.g. SSH keys) to substitute_env.sh
# which can trigger regex backtracking on unrelated lines.
write_minimal_env() {
  local tmp_env="$1"; shift
  : > "$tmp_env"
  for var in "$@"; do
    local val
    val=$(get_env_value "$var")
    printf '%s="%s"\n' "$var" "$val" >> "$tmp_env"
  done
}

echo "==> Creating appdata directories at $APPDATA"
sudo mkdir -p \
  "$APPDATA/homeassistant" \
  "$APPDATA/mqtt/config" \
  "$APPDATA/mqtt/data" \
  "$APPDATA/mqtt/log" \
  "$APPDATA/zigbee2mqtt"

echo "==> Copying mosquitto.conf"
sudo cp "$STACK_DIR/config/mosquitto.conf" "$APPDATA/mqtt/config/mosquitto.conf"

echo "==> Substituting zigbee2mqtt configuration"
write_minimal_env "$TMP_DIR/env.zigbee2mqtt" SLZB06_HOST
"$SCRIPT_DIR/substitute_env.sh" \
  "$STACK_DIR/config/zigbee2mqtt_configuration.yaml" \
  "$TMP_DIR/zigbee2mqtt_configuration.yaml" \
  "$TMP_DIR/env.zigbee2mqtt"
# Only copy on first-time setup — Z2M replaces GENERATE with real pan_id/network_key
# on first run and saves them back to this file. Overwriting it would cause a
# configuration-adapter mismatch on next restart.
if [[ ! -f "$APPDATA/zigbee2mqtt/configuration.yaml" ]]; then
  sudo cp "$TMP_DIR/zigbee2mqtt_configuration.yaml" "$APPDATA/zigbee2mqtt/configuration.yaml"
  echo "    Copied zigbee2mqtt configuration (first-time setup)"
else
  echo "    Skipped zigbee2mqtt configuration (already exists — preserving live config with real pan_id/network_key)"
fi

echo "==> Substituting Home Assistant configuration"
write_minimal_env "$TMP_DIR/env.ha" CADDY_OFFICE_PREFIX
"$SCRIPT_DIR/substitute_env.sh" \
  "$STACK_DIR/config/ha_configuration.yaml" \
  "$TMP_DIR/ha_configuration.yaml" \
  "$TMP_DIR/env.ha"
sudo cp "$TMP_DIR/ha_configuration.yaml" "$APPDATA/homeassistant/configuration.yaml"

echo "==> Generating docker-compose.homeassistant.yml"
write_minimal_env "$TMP_DIR/env.compose" TZ DOCKERLOGGING_MAXFILE DOCKERLOGGING_MAXSIZE
"$SCRIPT_DIR/substitute_env.sh" \
  "$STACK_DIR/template.yaml" \
  "$PARENT_DIR/docker-compose.homeassistant.yml" \
  "$TMP_DIR/env.compose"

echo ""
echo "Done. To deploy:"
echo "  docker compose -f $PARENT_DIR/docker-compose.homeassistant.yml up -d"
