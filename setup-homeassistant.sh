#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APPDATA="$PARENT_DIR/appdata"
STACK_DIR="$SCRIPT_DIR/docker-compose-files/homeassistant"
ENV_FILE="$SCRIPT_DIR/.env"

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
sudo "$SCRIPT_DIR/substitute_env.sh" \
  "$STACK_DIR/config/zigbee2mqtt_configuration.yaml" \
  "$APPDATA/zigbee2mqtt/configuration.yaml" \
  "$ENV_FILE"

echo "==> Substituting Home Assistant configuration"
sudo "$SCRIPT_DIR/substitute_env.sh" \
  "$STACK_DIR/config/ha_configuration.yaml" \
  "$APPDATA/homeassistant/configuration.yaml" \
  "$ENV_FILE"

echo "==> Generating docker-compose.homeassistant.yml"
"$SCRIPT_DIR/substitute_env.sh" \
  "$STACK_DIR/template.yaml" \
  "$PARENT_DIR/docker-compose.homeassistant.yml" \
  "$ENV_FILE"

echo ""
echo "Done. To deploy:"
echo "  docker compose -f $PARENT_DIR/docker-compose.homeassistant.yml up -d"
