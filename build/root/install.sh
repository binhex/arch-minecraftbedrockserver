#!/bin/bash

# exit script if return code != 0
set -e

# app name from buildx arg, used in healthcheck to identify app and monitor correct process
APPNAME="${1}"
shift

# release tag name from buildx arg, stripped of build ver using string manipulation
RELEASETAG="${1}"
shift

# target arch from buildx arg
TARGETARCH="${1}"
shift

if [[ -z "${APPNAME}" ]]; then
	echo "[warn] App name from build arg is empty, exiting script..."
	exit 1
fi

if [[ -z "${RELEASETAG}" ]]; then
	echo "[warn] Release tag name from build arg is empty, exiting script..."
	exit 1
fi

if [[ -z "${TARGETARCH}" ]]; then
	echo "[warn] Target architecture name from build arg is empty, exiting script..."
	exit 1
fi

# write APPNAME and RELEASETAG to file to record the app name and release tag used to build the image
echo -e "export APPNAME=${APPNAME}\nexport IMAGE_RELEASE_TAG=${RELEASETAG}\n" >> '/etc/image-build-info'

# ensure we have the latest builds scripts
refresh.sh

# pacman packages
####

# define pacman packages
pacman_packages="rsync screen"

# install compiled packages using pacman
if [[ -n "${pacman_packages}" ]]; then
	# arm64 currently targetting aor not archive, so we need to update the system first
	if [[ "${TARGETARCH}" == "arm64" ]]; then
		pacman -Syu --noconfirm
	fi
	pacman -S --needed $pacman_packages --noconfirm
fi

# github packages
####

download_path="/tmp/gotty"
install_path="/usr/bin"

mkdir -p "${download_path}" "${install_path}"

# binary asset download
gh.sh --github-owner sorenisanerd --github-repo gotty --download-type release --release-type binary --download-path "${download_path}" --asset-regex "gotty.*linux_${TARGETARCH}.tar.gz"

# unpack to install path
tar -xvf "${download_path}/"*.tar.gz -C "${install_path}"

# custom
####

# use env var RELEASETAG to get release version of minecraft bedrock (determined by tdb) stripped of build ver using string manipulation
release_version="${RELEASETAG//-[0-9][0-9]/}"

minecraft_bedrock_url="https://www.minecraft.net/bedrockdedicatedserver/bin-linux/bedrock-server-${release_version}.zip"

echo "[INFO] Web scrape URL for Bedrock is '${minecraft_bedrock_url}'"

# download compiled minecraft bedrock server
rcurl.sh -o "/tmp/minecraftbedrockserver.zip" "${minecraft_bedrock_url}"

# unzip minecraft bedrock server
mkdir -p "/srv/minecraft" && unzip "/tmp/minecraftbedrockserver.zip" -d "/srv/minecraft"

# enable mouse and keyboard scrolling for screen
cat <<EOF > /home/nobody/.screenrc
# Enable mouse scrolling and scroll bar history scrolling
termcapinfo xterm* ti@:te@
EOF

# download screen v4 from arch linux archive due to buffer overflow bug reported
# here:- https://gitlab.archlinux.org/archlinux/packaging/packages/screen/-/issues/2
curl -o /tmp/screen.tar.zst -L https://archive.archlinux.org/packages/s/screen/screen-4.9.1-2-x86_64.pkg.tar.zst
pacman -U /tmp/screen.tar.zst --noconfirm

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

# In install.sh heredoc, replace the chown section:
cat <<EOF > /tmp/permissions_heredoc
install_paths="${install_paths}"
EOF

# replace permissions placeholder string with contents of file (here doc)
sed -i '/# PERMISSIONS_PLACEHOLDER/{
    s/# PERMISSIONS_PLACEHOLDER//g
    r /tmp/permissions_heredoc
}' /usr/bin/init.sh
rm /tmp/permissions_heredoc

# env vars
####

cat <<'EOF' > /tmp/envvars_heredoc

# source in utility functions, need process_env_var
source utils.sh

# Define environment variables to process
# Format: "VAR_NAME:DEFAULT_VALUE:REQUIRED:MASK"
env_vars=(
	"CREATE_BACKUP_HOURS:12:false:false"
	"PURGE_BACKUP_DAYS:14:false:false"
	"ENABLE_WEBUI_CONSOLE:yes:false:false"
	"STARTUP_CMD::false:false"
	"ENABLE_STARTUP_SCRIPTS:no:false:false"
	"STARTUP_SCRIPTS_MODE:wait:false:false"
)

# Process each environment variable
for env_var in "${env_vars[@]}"; do
	IFS=':' read -r var_name default_value required mask_value <<< "${env_var}"
	process_env_var "${var_name}" "${default_value}" "${required}" "${mask_value}"
done

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
EOF

# replace env vars placeholder string with contents of file (here doc)
sed -i '/# ENVVARS_PLACEHOLDER/{
    s/# ENVVARS_PLACEHOLDER//g
    r /tmp/envvars_heredoc
}' /usr/bin/init.sh
rm /tmp/envvars_heredoc

# cleanup
cleanup.sh
