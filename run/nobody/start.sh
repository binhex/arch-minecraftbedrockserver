#!/bin/bash

# if minecraft server.properties file doesnt exist then copy default to host config volume
if [ ! -f "/config/minecraft/server.properties" ]; then

	echo "[info] Minecraft server.properties file doesnt exist, copying default installation to '/config/minecraft/'..."

	mkdir -p /config/minecraft
	if [[ -d "/srv/minecraft" ]]; then
		cp -R /srv/minecraft/* /config/minecraft/ 2>/dev/null || true
	fi

else

	# rsync options defined as follows:-
	# -r = recursive copy to destination
	# -l = copy source symlinks as symlinks on destination
	# -t = keep source modification times for destination files/folders
	# -p = keep source permissions for destination files/folders
	echo "[info] Minecraft folder '/config/minecraft' already exists, rsyncing newer files..."
	rsync -rltp --exclude 'worlds' --exclude '/server.properties' --exclude '/*.json' --exclude '*.debug' '/srv/minecraft/' '/config/minecraft'

fi

echo "[info] Starting Minecraft Bedrock process in screen session 'minecraft'..."
echo "[info] To attach to the screen session run:-"
echo "[info] docker exec -u nobody -it <container name> screen -r minecraft"
echo "[info] To detach from the screen session press:-"
echo "[info] CTRL+a and then release keys and press d"

# create logs sub folder to store screen output from console
mkdir -p /config/minecraft/logs

# run screen attached to minecraft (daemonized, non-blocking) to allow users to run commands in minecraft console
screen -L -Logfile '/config/minecraft/logs/screen.log' -d -S minecraft -m bash -c "cd /config/minecraft && ./bedrock_server"
echo "[info] Minecraft Bedrock process is running"
cat
