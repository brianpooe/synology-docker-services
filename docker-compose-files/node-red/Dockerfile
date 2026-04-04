FROM nodered/node-red:latest

# Install the Home Assistant websocket node into Node-RED's own module directory
# (/usr/src/node-red), NOT into /data — so the /data volume mount does not hide it.
RUN npm install --no-update-notifier --no-fund --omit=dev \
    node-red-contrib-home-assistant-websocket
