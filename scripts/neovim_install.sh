#!/usr/bin/env bash

# If anything fails, exit
set -eo pipefail

# Create a temporary directory to handle any remote nvim data location things
temp_dir=$(mktemp -d 2>/dev/null || mktemp -d -t 'neovim_download')

cleanup_function() {
	# Function to delete the directory, change "/path/to/directory" to the actual directory path
	rm -rf "$temp_dir"
}

# Set the trap to execute the cleanup_function on getting terminated
trap cleanup_function EXIT SIGTERM SIGINT

# Function to display usage information
function display_help() {
	cat <<EOM
Usage: $0 -v <nvim-version> -d <download-dir> [options]
Options:
  -v       Specify the desired Neovim version to install.
  -d       Specify directory for storing Neovim binaries.
           NOTE: Installation would happen in 'nvim-downloads' subdirectory.
  -f       Force installation. Would overwrite any existing installation.
  -o       Offline mode. Assume release is already downloaded.
  -h       Display this help message and exit.
EOM
}

# Function to check if Neovim is available in the system's $PATH
function check_neovim_in_path() {
	if command -v nvim &>/dev/null; then
		echo "Neovim already on PATH. Skipping installation..."
		exit 0
	fi
}

# Function to download files using curl or wget
function download() {
	local url="$1"
	local output_file="$2"

	if [ "$downloader" = "curl" ]; then
		curl -fsSL -o "$output_file" "$url"
	elif [ "$downloader" = "wget" ]; then
		wget --quiet --output-document="$output_file" "$url"
	fi
}

# Install on Linux using AppImage
function setup_neovim_linux_appimage() {
	local nvim_release_name="nvim-$1-linux.appimage"
	local nvim_appimage_temp_path="$temp_dir/$nvim_release_name"

	if [ ! -e "$nvim_version_dir/$nvim_release_name" ]; then
		echo "Expected release to be present at $nvim_version_dir/$nvim_release_name. Aborting..."
		exit 1
	fi

	cp "$nvim_version_dir/$nvim_release_name" "$nvim_appimage_temp_path"

	echo "Extracting Neovim binary..."
	chmod u+x "$nvim_appimage_temp_path"
	"$nvim_appimage_temp_path" --appimage-extract >/dev/null

	echo "Finishing up installing Neovim..."
	mkdir -p "$nvim_version_dir"/bin
	mv -f "$temp_dir/squashfs-root"/* "$nvim_version_dir"
	ln -sf "$nvim_version_dir"/AppRun "$nvim_binary"
}

# Function to download and decompress Neovim binary for macOS
function setup_neovim_macos() {
	local nvim_release_name="nvim-$1-macos.tar.gz"
	local nvim_macos_tar_path="$temp_dir/$nvim_release_name"
	cp "$nvim_version_dir/$nvim_release_name" "$nvim_macos_tar_path"

	if [ ! -e "$nvim_version_dir/$nvim_release_name" ]; then
		echo "Expected release to be present at $nvim_version_dir/$nvim_release_name"
		exit 1
	fi

	echo "Extracting Neovim binary..."
	tar -xzf "$nvim_macos_tar_path" -C "$temp_dir"

	echo "Finishing up Neovim installation..."
	mkdir -p "$nvim_version_dir"
	mv -f "$temp_dir"/nvim-macos/* "$nvim_version_dir"

	echo "Neovim installation completed!"
}

# Function to install Neovim
function install_neovim() {
	# Check if the specified download directory exists
	if [[ ! -d $remote_nvim_dir ]]; then
		echo "Remote neovim directory does not exist. Creating it now..."
		mkdir -p "$remote_nvim_dir"
	fi
	nvim_download_dir="$remote_nvim_dir/nvim-downloads"

	# Check if the specified release is already downloaded
	nvim_version_dir="$nvim_download_dir/$nvim_version"
	nvim_binary="$nvim_version_dir/bin/nvim"

	if [[ ! $force_installation && -d $nvim_version_dir && $($nvim_binary -v 2>/dev/null | head -c1 | wc -c) -ne 0 ]]; then
		echo "Neovim ${nvim_version} is already installed. Skipping installation."
	else
		if [[ -d $nvim_version_dir && $($nvim_binary -v 2>/dev/null | head -c1 | wc -c) -eq 0 ]]; then
			echo "Neovim installation is corrupted. Would re-install..."
		fi

		mkdir -p "$nvim_version_dir"
		local os
		os=$(uname)

		if [ "$offline_mode" == true ]; then
			echo "Operating in offline mode. Will not download Neovim release"
		else
			# Check if either curl or wget is available on the system
			if command -v curl &>/dev/null; then
				downloader="curl"
			elif command -v wget &>/dev/null; then
				downloader="wget"
			else
				echo "Error: This script requires either curl or wget to be installed."
				exit 1
			fi

			"$download_neovim_script" -o "$os" -v "$nvim_version" -d "$nvim_version_dir"
		fi

		# Install Neovim based on the detected OS
		if [[ $os == "Linux" ]]; then
			setup_neovim_linux_appimage "$nvim_version"
		elif [[ $os == "Darwin" ]]; then
			setup_neovim_macos "$nvim_version"
		else
			echo "Unsupported operating system: $(uname)"
			exit 1
		fi

	fi

	echo "Neovim $nvim_version can be accessed at $nvim_binary"
}

# Parse command-line options
while getopts "v:d:h:fo" opt; do
	case $opt in
	v)
		nvim_version="$OPTARG"
		;;
	d)
		remote_nvim_dir="$OPTARG"
		;;
	f)
		force_installation=true
		;;
	o)
		offline_mode=true
		;;
	h)
		display_help
		exit 0
		;;
	\?)
		display_help
		exit 1
		;;
	:)
		echo "Option -$OPTARG requires an argument." >&2
		display_help
		exit 1
		;;
	esac
done

# Check if the required options are provided
if [[ -z $nvim_version || -z $remote_nvim_dir ]]; then
	echo "Missing options. Use -h to see the usage."
	exit 1
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
download_neovim_script="$SCRIPT_DIR/neovim_download.sh"
cd "$temp_dir" || exit 1
install_neovim
