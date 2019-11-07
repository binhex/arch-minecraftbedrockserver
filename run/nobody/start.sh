#!/bin/bash

# if minecraft folder doesnt exist then copy default to host config volume
if [ ! -d "/config/minecraft" ]; then

	echo "[info] Minecraft folder doesnt exist, copying default to '/config/minecraft/'..."

	mkdir -p /config/minecraft
	if [[ -d "/srv/minecraft" ]]; then
		cp -R /srv/minecraft/* /config/minecraft/ 2>/dev/null || true
	fi

else

	echo "[info] Minecraft folder '/config/minecraft' already exists, rsyncing newer files..."
	rsync -ur --exclude 'worlds' --exclude 'server.properties' --exclude '*.json' /srv/minecraft/ /config/minecraft

fi

echo "[info] Starting Minecraft bedrock process..."
cd "/config/minecraft" && ./bedrock_server
