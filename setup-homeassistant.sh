#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APPDATA="$PARENT_DIR/appdata"
STACK_DIR="$SCRIPT_DIR/docker-compose-files/homeassistant"
ENV_FILE="$SCRIPT_DIR/.env"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "==> Checking required .env variables"
REQUIRED_VARS=(TZ SLZB06_HOST DOCKERLOGGING_MAXFILE DOCKERLOGGING_MAXSIZE)
MISSING=()

get_env_value() {
  local key="$1"
  local line value
  line=$(grep -E "^${key}=" "$ENV_FILE" 2>/dev/null | head -1) || true
  value="${line#*=}"
  # Strip surrounding quotes
  if [[ "$value" =~ ^\"(.*)\"[[:space:]]*(#.*)?$ ]]; then
    value="${BASH_REMATCH[1]}"
  elif [[ "$value" =~ ^\'(.*)\'[[:space:]]*(#.*)?$ ]]; then
    value="${BASH_REMATCH[1]}"
  fi
  printf '%s' "$value"
}

for var in "${REQUIRED_VARS[@]}"; do
  value=$(get_env_value "$var")
  if [[ -z "$value" ]]; then
    MISSING+=("$var")
  fi
done
if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "Error: missing required variables in .env:"
  for var in "${MISSING[@]}"; do echo "  - $var"; done
  exit 1
fi

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
"$SCRIPT_DIR/substitute_env.sh" \
  "$STACK_DIR/config/zigbee2mqtt_configuration.yaml" \
  "$TMP_DIR/zigbee2mqtt_configuration.yaml" \
  "$ENV_FILE"
sudo cp "$TMP_DIR/zigbee2mqtt_configuration.yaml" "$APPDATA/zigbee2mqtt/configuration.yaml"

echo "==> Substituting Home Assistant configuration"
"$SCRIPT_DIR/substitute_env.sh" \
  "$STACK_DIR/config/ha_configuration.yaml" \
  "$TMP_DIR/ha_configuration.yaml" \
  "$ENV_FILE"
sudo cp "$TMP_DIR/ha_configuration.yaml" "$APPDATA/homeassistant/configuration.yaml"

echo "==> Generating docker-compose.homeassistant.yml"
"$SCRIPT_DIR/substitute_env.sh" \
  "$STACK_DIR/template.yaml" \
  "$PARENT_DIR/docker-compose.homeassistant.yml" \
  "$ENV_FILE"

echo ""
echo "Done. To deploy:"
echo "  docker compose -f $PARENT_DIR/docker-compose.homeassistant.yml up -d"
