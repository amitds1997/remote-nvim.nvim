#!/usr/bin/env bash

# If anything fails, exit
set -eo pipefail

# Create a temporary directory to handle any remote nvim data location things
temp_dir=$(mktemp -d 2>/dev/null || mktemp -d -t 'neovim_download')
cd "$temp_dir" || exit 1

cleanup_function() {
	# Function to delete the directory, change "/path/to/directory" to the actual directory path
	rm -rf "$temp_dir"
}

# Set the trap to execute the cleanup_function on getting terminated
trap cleanup_function EXIT SIGTERM SIGINT

# Function to display usage information
function display_help() {
	cat <<EOM
Usage: $0 -v <nvim-version> -d <download-dir> -m <install-method> [options]
Options:
  -v       Specify the desired Neovim version to install.
  -d       Specify directory for storing Neovim binaries.
           NOTE: Installation would happen in 'nvim-downloads' subdirectory.
  -m       Installation method. Can be: default, build_from_source, and link_to_system_neovim
  -f       Force installation. Would overwrite any existing installation.
  -h       Display this help message and exit.
EOM
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

# Build Neovim from source and link it
function build_from_source() {
	local nvim_version="$1"
	local download_url="https://github.com/neovim/neovim/archive/refs/tags/${nvim_version}.tar.gz"

	echo "Downloading Neovim source..."
	download "$download_url" "$temp_dir/nvim-source.tar.gz"

	echo "Extracting Neovim source..."
	tar -xzf "$temp_dir/nvim-source.tar.gz" -C "$temp_dir"

	echo "Creating necessary directories..."
	rm -rf "$nvim_version_dir"
	mkdir -p "$nvim_version_dir"/bin

	os_name=$(uname)
	make="make"
	if [[ $os_name == "FreeBSD" || $os_name == "OpenBSD" ]]; then
		make="gmake"
	fi

	echo "Building Neovim..."
	$make -C neovim-* CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX="$nvim_version_dir" install

	echo "Finishing up..."
	cp -r ./neovim-*/ "$nvim_version_dir"
	ln -sf "$nvim_version_dir"/build/bin/nvim "$nvim_binary"
}

# Link to system Neovim
function link_to_system_neovim() {
	if command -v nvim &>/dev/null; then
		rm -rf "$nvim_version_dir"
		mkdir -p "$nvim_version_dir"/bin
		nvim_path=$(which nvim)
		ln -sf "$nvim_path" "$nvim_binary"
	else
		echo "Error: Did not find Neovim on the path"
		exit 1
	fi
}

# Install on Linux using AppImage
function download_decompress_neovim_linux_appimage() {
	local nvim_version="$1"
	local download_url="https://github.com/neovim/neovim/releases/download/${nvim_version}/nvim.appimage"

	echo "Downloading Neovim for Linux (AppImage)..."
	download "$download_url" "$temp_dir/nvim.appimage"

	echo "Extracting Neovim binary..."
	chmod u+x "$temp_dir/nvim.appimage"
	"$temp_dir/nvim.appimage" --appimage-extract >/dev/null

	echo "Finishing up installing Neovim..."
	rm -rf "$nvim_version_dir"
	mkdir -p "$nvim_version_dir"/bin
	mv -f "$temp_dir/squashfs-root"/* "$nvim_version_dir"
	ln -sf "$nvim_version_dir"/usr/bin/nvim "$nvim_binary"
}

# Function to download and decompress Neovim binary for macOS
function download_decompress_neovim_macOS() {
	local nvim_version="$1"
	local download_url="https://github.com/neovim/neovim/releases/download/${nvim_version}/nvim-macos.tar.gz"

	echo "Downloading Neovim for macOS..."
	download "$download_url" "$temp_dir/nvim-macos.tar.gz"

	echo "Extracting Neovim binary..."
	tar -xzf "$temp_dir/nvim-macos.tar.gz" -C "$temp_dir"

	echo "Finishing up Neovim installation..."
	rm -rf "$nvim_version_dir"
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

		# Check if either curl or wget is available on the system
		if command -v curl &>/dev/null; then
			downloader="curl"
		elif command -v wget &>/dev/null; then
			downloader="wget"
		else
			echo "Error: This script requires either curl or wget to be installed."
			exit 1
		fi

		os_name="$(uname)"

		if [[ $install_method == "default" ]]; then
			# Install Neovim based on the detected OS
			if [[ $os_name == "Linux" ]]; then
				download_decompress_neovim_linux_appimage "$nvim_version"
			elif [[ $os_name == "Darwin" ]]; then
				download_decompress_neovim_macOS "$nvim_version"
			elif [[ $os_name == "FreeBSD" ]]; then
				download_decompress_neovim_linux_appimage "$nvim_version"
			else
				echo "Unsupported operating system: $(uname)"
				exit 1
			fi
		elif [[ $install_method == "build_from_source" ]]; then
			build_from_source "$nvim_version"
		elif [[ $install_method == "link_to_system_neovim" ]]; then
			link_to_system_neovim
		else
			echo "Unknown installation method. Available install methods: default, link_to_system_neovim or build_from_source"
			exit 1
		fi
	fi

	echo "Neovim $nvim_version can be accessed at $nvim_binary"
}

# Parse command-line options
while getopts "v:d:h:m:f" opt; do
	case $opt in
	v)
		nvim_version="$OPTARG"
		;;
	d)
		remote_nvim_dir="$OPTARG"
		;;
	m)
		install_method="$OPTARG"
		;;
	f)
		force_installation=true
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
if [[ -z $nvim_version || -z $remote_nvim_dir || -z $install_method ]]; then
	echo "Missing options. Use -h to see the usage."
	exit 1
fi

if [[ $install_method == "link_to_system_neovim" ]]; then
	if [[ $nvim_version != "system" ]]; then
		echo "Only accepted Neovim version for linking to system Neovim is: system"
		exit 1
	fi
elif [[ $nvim_version != "stable" && $nvim_version != "nightly" && ! $nvim_version =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	echo "Invalid version: $nvim_version"
	exit 1
fi

install_neovim
