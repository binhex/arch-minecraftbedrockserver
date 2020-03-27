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

echo "[info] Starting Minecraft Bedrock process in tmux session 'minecraft'..."
echo "[info] To attach to the tmux session run:-"
echo "[info] docker exec -u nobody -it <container name> tmux a -t minecraft"
echo "[info] To detach from the tmux session press:-"
echo "[info] CTRL+b and then release keys and press d"

# run tmux attached to minecraft (daemonized, non-blocking) to allow users to run commands in minecraft console
/usr/bin/script /home/nobody/typescript --command "/usr/bin/tmux new-session -d -s minecraft -n minecraft 'cd /config/minecraft && ./bedrock_server'"
echo "[info] Minecraft bedrock process is running"
cat
