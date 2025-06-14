**Application**

[Minecraft Bedrock Edition](https://www.minecraft.net/en-us/download/server/bedrock)

**Description**

Minecraft is a sandbox video game created by Swedish game developer Markus Persson and released by Mojang in 2011. The game allows players to build with a variety of different blocks in a 3D procedurally generated world, requiring creativity from players. Other activities in the game include exploration, resource gathering, crafting, and combat. Multiple game modes that change gameplay are available, including—but not limited to—a survival mode, in which players must acquire resources to build the world and maintain health, and a creative mode, where players have unlimited resources to build with.

**Build notes**

Latest alpha Minecraft Bedrock release from Mojang.

**Usage**
```
docker run -d \
    --net="bridge" \
    --name=<container name> \
    -p <host port>:8222/tcp \
    -p <host port>:19132/tcp \
    -p <host port>:19132/udp \
    -p <host port>:19133/tcp \
    -p <host port>:19133/udp \
    -v <path for config files>:/config \
    -v /etc/localtime:/etc/localtime:ro \
    -e CREATE_BACKUP_HOURS=<frequency of world backups in hours> \
    -e PURGE_BACKUP_DAYS=<specify oldest world backups to keep in days> \
    -e ENABLE_WEBUI_CONSOLE=<yes|no> \
    -e ENABLE_WEBUI_AUTH=<yes|no> \
    -e WEBUI_USER=<specify webui username> \
    -e WEBUI_PASS=<specify webui password> \
    -e WEBUI_CONSOLE_TITLE=<specify webui console title> \
    -e STARTUP_CMD=<minecraft console command to execute on startup> \
    -e UMASK=<umask for created files> \
    -e PUID=<uid for user> \
    -e PGID=<gid for user> \
    binhex/arch-minecraftbedrockserver
```
&nbsp;
Please replace all user variables in the above command defined by <> with the correct values.

**Access Minecraft Server console**

Requires `-e ENABLE_WEBUI_CONSOLE=yes`

`http://<host ip>:8222`

**Example**
```
docker run -d \
    --net="bridge" \
    --name=minecraftbedrockserver \
    -p 8222:8222/tcp \
    -p 19132:19132/tcp \
    -p 19132:19132/udp \
    -p 19133:19133/tcp \
    -p 19133:19133/udp \
    -v /apps/docker/minecraftbedrockserver:/config \
    -v /etc/localtime:/etc/localtime:ro \
    -e CREATE_BACKUP_HOURS=12 \
    -e PURGE_BACKUP_DAYS=14 \
    -e ENABLE_WEBUI_CONSOLE=yes \
    -e ENABLE_WEBUI_AUTH=yes \
    -e WEBUI_USER=admin \
    -e WEBUI_PASS=minecraft \
    -e WEBUI_CONSOLE_TITLE='Minecraft Bedrock' \
    -e STARTUP_CMD=gamerule showcoordinates true \
    -e UMASK=000 \
    -e PUID=0 \
    -e PGID=0 \
    binhex/arch-minecraftbedrockserver
```
**Backups**

If you do **NOT** want world backups and/or purging of backups then set the value to '0' for env vars 'CREATE_BACKUP_HOURS' and/or 'PURGE_BACKUP_DAYS'.

Backups are zipped into the /config/backups folder.

**Notes**

User ID (PUID) and Group ID (PGID) can be found by issuing the following command for the user you want to run the container as:-

```
id <username>
```
___
If you appreciate my work, then please consider buying me a beer  :D

[![PayPal donation](https://www.paypal.com/en_US/i/btn/btn_donate_SM.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=MM5E27UX6AUU4)

[Documentation](https://github.com/binhex/documentation) | [Support forum](https://forums.unraid.net/topic/84905-support-binhex-minecraftbedrockserver/)
