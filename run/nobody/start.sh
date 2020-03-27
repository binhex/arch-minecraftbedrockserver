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
	rsync -rltp --exclude 'worlds' --exclude '/server.properties' --exclude '/*.json' /srv/minecraft/ /config/minecraft

fi

echo "[info] Starting Minecraft Bedrock process in screen session 'minecraft'..."
echo "[info] To attach to the screen session run:-"
echo "[info] docker exec -u nobody -it <container name> screen -r minecraft"
echo "[info] To detach from the screen session press:-"
echo "[info] CTRL+a and then release keys and press d"

# run screen attached to minecraft (daemonized, non-blocking) to allow users to run commands in minecraft console
screen -d -S minecraft -m bash -c "cd /config/minecraft && ./bedrock_server"
echo "[info] Minecraft Bedrock process is running"
cat
