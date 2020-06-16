#!/bin/bash

# script to create a webui minecraft console using utility 'gotty'

if [[ "${ENABLE_WEBUI_CONSOLE}" == "yes" ]]; then

	echo "[info] Starting Minecraft console Web UI..."
	gotty --port=8222 --title-format "${WEBUI_CONSOLE_TITLE}" --permit-write screen -r minecraft

else

	echo "[info] Minecraft console Web UI not enabled"

fi
