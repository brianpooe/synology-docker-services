#!/bin/bash
#chmod +x check_container_ips.sh
# Array of containers
VPN_CONTAINERS=("gluetun" "prowlarr" "qbittorrent" "sabnzbd")
NON_VPN_CONTAINERS=("radarr" "sonarr" "bazarr" "flaresolverr" "emby" "jellyseerr")

echo "Checking IP addresses of containers using VPN..."

# Check VPN containers
for container in "${VPN_CONTAINERS[@]}"; do
  echo -n "Container: $container - IP: "
  if [ "$container" == "gluetun" ]; then
    sudo docker exec -it "$container" wget -qO index.html ipconfig.io \
      && sudo docker exec -it "$container" cat index.html \
      || echo "Error fetching IP"
  else
    sudo docker exec -it "$container" curl -s ipconfig.io || echo "Error fetching IP"
  fi
done

echo ""
echo "Checking IP addresses of containers not using VPN..."

# Check non-VPN containers
for container in "${NON_VPN_CONTAINERS[@]}"; do
  echo -n "Container: $container - IP: "
  sudo docker exec -it "$container" curl -s ipconfig.io || echo "Error fetching IP"
done
