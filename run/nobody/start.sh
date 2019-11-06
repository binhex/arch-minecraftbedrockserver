#!/bin/bash

# if minecraft folder doesnt exist then copy default to host config volume (soft linked)
if [ ! -d "/config/minecraft" ]; then

	echo "[info] Minecraft folder doesnt exist, copying default to /config/minecraft/..."

	mkdir -p /config/minecraft
	if [[ -d "/srv/minecraft" ]]; then
		cp -R /srv/minecraft/* /config/minecraft/ 2>/dev/null || true
	fi

else

	echo "[info] Minecraft folder already exists, skipping copy"

fi

echo "[info] Starting Minecraft bedrock process..."
cd "/config/minecraft" && ./bedrock_server
