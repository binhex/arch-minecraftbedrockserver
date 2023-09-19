#!/bin/bash

# exit script if return code != 0
set -e

# release tag name from build arg, stripped of build ver using string manipulation
RELEASETAG="${1//-[0-9][0-9]/}"

if [[ -z "${RELEASETAG}" ]]; then
	echo "[warn] Release tag name from build arg is empty, exiting script..."
	exit 1
fi

# build scripts
####

# download build scripts from github
curl --connect-timeout 5 --max-time 600 --retry 5 --retry-delay 0 --retry-max-time 60 -o /tmp/scripts-master.zip -L https://github.com/binhex/scripts/archive/master.zip

# unzip build scripts
unzip /tmp/scripts-master.zip -d /tmp

# move shell scripts to /root
mv /tmp/scripts-master/shell/arch/docker/*.sh /usr/local/bin/

# detect image arch
####

# get target arch from Dockerfile argument
TARGETARCH="${2}"

# pacman packages
####

# define pacman packages
pacman_packages="rsync screen"

# install compiled packages using pacman
if [[ ! -z "${pacman_packages}" ]]; then
	pacman -S --needed $pacman_packages --noconfirm
fi

# aur packages
####

# define aur packages
aur_packages=""

# call aur install script (arch user repo)
source aur.sh

# github packages
####

# download gotty which gives us minecraft console in web ui
if [[ "${TARGETARCH}" == "amd64" ]]; then
	github.sh --install-path /usr/bin --github-owner yudai --github-repo gotty --download-assets gotty_linux_amd64.tar.gz
elif [[ "${TARGETARCH}" == "arm64" ]]; then
	github.sh --install-path /usr/bin --github-owner yudai --github-repo gotty --download-assets gotty_linux_arm.tar.gz
else
	echo "[warn] Unable to identify valid architecture for Gotty tooling, exiting script..."
	exit 1
fi

# custom
####

minecraft_bedrock_url="https://minecraft.azureedge.net/bin-linux/bedrock-server-${RELEASETAG}.zip"

echo "[INFO] Web scrape URL for Bedrock is '${minecraft_bedrock_url}'"

# download compiled minecraft bedrock server
rcurl.sh -o "/tmp/minecraftbedrockserver.zip" "${minecraft_bedrock_url}"

# unzip minecraft bedrock server
mkdir -p "/srv/minecraft" && unzip "/tmp/minecraftbedrockserver.zip" -d "/srv/minecraft"

# container perms
####

# define comma separated list of paths
install_paths="/srv,/home/nobody"

# split comma separated string into list for install paths
IFS=',' read -ra install_paths_list <<< "${install_paths}"

# process install paths in the list
for i in "${install_paths_list[@]}"; do

	# confirm path(s) exist, if not then exit
	if [[ ! -d "${i}" ]]; then
		echo "[crit] Path '${i}' does not exist, exiting build process..." ; exit 1
	fi

done

# convert comma separated string of install paths to space separated, required for chmod/chown processing
install_paths=$(echo "${install_paths}" | tr ',' ' ')

# set permissions for container during build - Do NOT double quote variable for install_paths otherwise this will wrap space separated paths as a single string
chmod -R 775 ${install_paths}

# create file with contents of here doc, note EOF is NOT quoted to allow us to expand current variable 'install_paths'
# we use escaping to prevent variable expansion for PUID and PGID, as we want these expanded at runtime of init.sh
cat <<EOF > /tmp/permissions_heredoc

# get previous puid/pgid (if first run then will be empty string)
previous_puid=\$(cat "/root/puid" 2>/dev/null || true)
previous_pgid=\$(cat "/root/pgid" 2>/dev/null || true)

# if first run (no puid or pgid files in /tmp) or the PUID or PGID env vars are different
# from the previous run then re-apply chown with current PUID and PGID values.
if [[ ! -f "/root/puid" || ! -f "/root/pgid" || "\${previous_puid}" != "\${PUID}" || "\${previous_pgid}" != "\${PGID}" ]]; then

	# set permissions inside container - Do NOT double quote variable for install_paths otherwise this will wrap space separated paths as a single string
	chown -R "\${PUID}":"\${PGID}" ${install_paths}

fi

# write out current PUID and PGID to files in /root (used to compare on next run)
echo "\${PUID}" > /root/puid
echo "\${PGID}" > /root/pgid

EOF

# replace permissions placeholder string with contents of file (here doc)
sed -i '/# PERMISSIONS_PLACEHOLDER/{
    s/# PERMISSIONS_PLACEHOLDER//g
    r /tmp/permissions_heredoc
}' /usr/local/bin/init.sh
rm /tmp/permissions_heredoc

# env vars
####

cat <<'EOF' > /tmp/envvars_heredoc

export CREATE_BACKUP_HOURS=$(echo "${CREATE_BACKUP_HOURS}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${CREATE_BACKUP_HOURS}" ]]; then
	echo "[info] CREATE_BACKUP_HOURS defined as '${CREATE_BACKUP_HOURS}'" | ts '%Y-%m-%d %H:%M:%.S'
else
	echo "[info] CREATE_BACKUP_HOURS not defined,(via -e CREATE_BACKUP_HOURS), defaulting to '12'" | ts '%Y-%m-%d %H:%M:%.S'
	export CREATE_BACKUP_HOURS="12"
fi

export PURGE_BACKUP_DAYS=$(echo "${PURGE_BACKUP_DAYS}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${PURGE_BACKUP_DAYS}" ]]; then
	echo "[info] PURGE_BACKUP_DAYS defined as '${PURGE_BACKUP_DAYS}'" | ts '%Y-%m-%d %H:%M:%.S'
else
	echo "[info] PURGE_BACKUP_DAYS not defined,(via -e PURGE_BACKUP_DAYS), defaulting to '14'" | ts '%Y-%m-%d %H:%M:%.S'
	export PURGE_BACKUP_DAYS="14"
fi

export ENABLE_WEBUI_CONSOLE=$(echo "${ENABLE_WEBUI_CONSOLE}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${ENABLE_WEBUI_CONSOLE}" ]]; then
	echo "[info] ENABLE_WEBUI_CONSOLE defined as '${ENABLE_WEBUI_CONSOLE}'" | ts '%Y-%m-%d %H:%M:%.S'
else
	echo "[info] ENABLE_WEBUI_CONSOLE not defined,(via -e ENABLE_WEBUI_CONSOLE), defaulting to 'yes'" | ts '%Y-%m-%d %H:%M:%.S'
	export ENABLE_WEBUI_CONSOLE="yes"
fi

if [[ "${ENABLE_WEBUI_CONSOLE}" == "yes" ]]; then
	export ENABLE_WEBUI_AUTH=$(echo "${ENABLE_WEBUI_AUTH}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
	if [[ ! -z "${ENABLE_WEBUI_AUTH}" ]]; then
		echo "[info] ENABLE_WEBUI_AUTH defined as '${ENABLE_WEBUI_AUTH}'" | ts '%Y-%m-%d %H:%M:%.S'
	else
		echo "[warn] ENABLE_WEBUI_AUTH not defined (via -e ENABLE_WEBUI_AUTH), defaulting to 'yes'" | ts '%Y-%m-%d %H:%M:%.S'
		export ENABLE_WEBUI_AUTH="yes"
	fi

	if [[ $ENABLE_WEBUI_AUTH == "yes" ]]; then
		export WEBUI_USER=$(echo "${WEBUI_USER}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
		if [[ ! -z "${WEBUI_USER}" ]]; then
			echo "[info] WEBUI_USER defined as '${WEBUI_USER}'" | ts '%Y-%m-%d %H:%M:%.S'
		else
			echo "[warn] WEBUI_USER not defined (via -e WEBUI_USER), defaulting to 'admin'" | ts '%Y-%m-%d %H:%M:%.S'
			export WEBUI_USER="admin"
		fi

		export WEBUI_PASS=$(echo "${WEBUI_PASS}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
		if [[ ! -z "${WEBUI_PASS}" ]]; then
			if [[ "${WEBUI_PASS}" == "minecraft" ]]; then
				echo "[warn] WEBUI_PASS defined as '${WEBUI_PASS}' is weak, please consider using a stronger password" | ts '%Y-%m-%d %H:%M:%.S'
			else
				echo "[info] WEBUI_PASS defined as '${WEBUI_PASS}'" | ts '%Y-%m-%d %H:%M:%.S'
			fi
		else
			WEBUI_PASS_file="/config/minecraft/security/WEBUI_PASS"
			if [ ! -f "${WEBUI_PASS_file}" ]; then
				# generate random password for web ui using SHA to hash the date,
				# run through base64, and then output the top 16 characters to a file.
				mkdir -p "/config/minecraft/security" ; chown -R nobody:users "/config/minecraft"
				date +%s | sha256sum | base64 | head -c 16 > "${WEBUI_PASS_file}"
			fi
			echo "[warn] WEBUI_PASS not defined (via -e WEBUI_PASS), using randomised password (password stored in '${WEBUI_PASS_file}')" | ts '%Y-%m-%d %H:%M:%.S'
			export WEBUI_PASS="$(cat ${WEBUI_PASS_file})"
		fi
	fi

	export WEBUI_CONSOLE_TITLE=$(echo "${WEBUI_CONSOLE_TITLE}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
	if [[ ! -z "${WEBUI_CONSOLE_TITLE}" ]]; then
		echo "[info] WEBUI_CONSOLE_TITLE defined as '${WEBUI_CONSOLE_TITLE}'" | ts '%Y-%m-%d %H:%M:%.S'
	else
		echo "[info] WEBUI_CONSOLE_TITLE not defined (via -e WEBUI_CONSOLE_TITLE), defaulting to 'Minecraft Bedrock'" | ts '%Y-%m-%d %H:%M:%.S'
		export WEBUI_CONSOLE_TITLE="Minecraft Bedrock"
	fi

fi

export STARTUP_CMD=$(echo "${STARTUP_CMD}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${STARTUP_CMD}" ]]; then
	echo "[info] STARTUP_CMD defined as '${STARTUP_CMD}'" | ts '%Y-%m-%d %H:%M:%.S'
else
	echo "[info] STARTUP_CMD not defined (via -e STARTUP_CMD)" | ts '%Y-%m-%d %H:%M:%.S'
fi

EOF

# replace env vars placeholder string with contents of file (here doc)
sed -i '/# ENVVARS_PLACEHOLDER/{
    s/# ENVVARS_PLACEHOLDER//g
    r /tmp/envvars_heredoc
}' /usr/local/bin/init.sh
rm /tmp/envvars_heredoc

# cleanup
cleanup.sh
