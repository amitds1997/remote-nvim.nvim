#!/usr/bin/env bash

# If anything fails, exit
set -eo pipefail

# Check if either curl or wget is available on the system
if command -v curl &>/dev/null; then
	downloader="curl"
elif command -v wget &>/dev/null; then
	downloader="wget"
else
	echo "Error: This script requires either curl or wget to be installed."
	exit 1
fi

function display_help() {
	cat <<EOM
Usage: $0 -v <nvim-version> -d <download-path> -o <os-name> -t <download-type>
Options:
  -v       Specify the desired Neovim version to download.
  -d       Specify directory inside which Neovim release should be downloaded.
  -o       OS whose binary is to be downloaded.
  -t       What to download: 'binary' or 'source'
  -a       Specify architecture that should be downloaded.
  -h       Display this help message and exit.
EOM
}

# Download using wget/curl whatever is available
function download() {
	local url="$1"
	local output_file="$2"

	if [ "$downloader" = "curl" ]; then
		curl -fsSL -o "$output_file" "$url"
	elif [ "$downloader" = "wget" ]; then
		wget --quiet --output-document="$output_file" "$url"
	fi
}

function download_neovim() {
	local os="$1"
	local version="$2"
	local download_dir="$3"
	local arch_type="$4"
	local download_url=""
	local download_path=""

	if [ "$os" == "Linux" ]; then
		download_url="https://github.com/neovim/neovim/releases/download/${version}/nvim.appimage"
		download_path="$download_dir/nvim-$version-linux.appimage"
	elif [ "$os" == "Darwin" ]; then
		download_url="https://github.com/neovim/neovim/releases/download/${version}/nvim-macos.tar.gz"
		download_path="$download_dir/nvim-$version-macos.tar.gz"

		set +e # Prevent termination based on compare_version's return
		compare_versions "$version" v0.9.5
		local result=$?
		set -e # Re-enable termination based on return values

		if [[ $version == "nightly" ]] || [[ $version == "stable" ]] || [[ $result -eq 1 ]]; then
			download_url="https://github.com/neovim/neovim/releases/download/${version}/nvim-macos-${arch_type}.tar.gz"
			download_path="$download_dir/nvim-$version-macos-$arch_type.tar.gz"
		fi
	else
		echo "Error: Currently download support is present only for Linux and macOS"
		exit 1
	fi

	local checksum_path="$download_path".sha256sum
	local expected_checksum=""
	# This ensures that they do not match
	local actual_checksum="$expected_checksum-actual"

	if [ -e "$download_path" ] && [ -e "$checksum_path" ]; then
		expected_checksum=$(cut -d ' ' -f 1 <"$checksum_path")
		actual_checksum=$(sha256sum "$download_path" | cut -d ' ' -f 1)
	fi

	if [ "$actual_checksum" == "$expected_checksum" ]; then
		echo "Existing installation with matching checksum found. Skipping downloading..."
		return 0
	fi

	echo "Downloading Neovim..."
	download "$download_url" "$download_path"
	download "$download_url".sha256sum "$checksum_path"
	echo "Download completed."
}

# Download Neovim source
function download_neovim_source() {
	local version="$1"
	local download_dir="$2"
	local download_url="https://github.com/neovim/neovim/archive/refs/tags/${version}.tar.gz"

	echo "Downloading Neovim source..."
	download "$download_url" "$download_dir/nvim-${version}-source.tar.gz"

	echo "Source download completed."
}

# Parse command-line options
while getopts "v:d:o:t:a:h" opt; do
	case $opt in
	v)
		nvim_version="$OPTARG"
		;;
	d)
		download_dir="$OPTARG"
		;;
	o)
		os_name="$OPTARG"
		;;
	t)
		download_type="$OPTARG"
		;;
	a)
		arch_type="$OPTARG"
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
if [[ -z $nvim_version || -z $download_dir || -z $download_type || -z $arch_type ]]; then
	echo "Missing options. Use -h to see the usage."
	exit 1
fi

if [[ $download_dir == *"remote-nvim.nvim/version_cache"* ]]; then
	echo "$download_dir is the default path. So, recursively creating the necessary directories"
	mkdir -p "$download_dir"
fi

if [[ ! -d $download_dir ]]; then
	echo "$download_dir does not exist. Will try creating it now.."
	if ! mkdir "$download_dir"; then
		echo "$download_dir creation failed as parent directories do not exist"
		exit 1
	else
		echo "Created $download_dir successfully"
	fi
fi

if [[ $nvim_version != "stable" && $nvim_version != "nightly" && ! $nvim_version =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	echo "Invalid Neovim version: $nvim_version"
	exit 1
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=./scripts/neovim_utils.sh
source "$SCRIPT_DIR/neovim_utils.sh"

if [[ $download_type == "source" ]]; then
	download_neovim_source "$nvim_version" "$download_dir"
elif [[ $download_type == "system" ]]; then
	echo "Cannot download a system-type Neovim release. Choose from either 'source' or 'binary'."
	exit 1
else
	download_neovim "$os_name" "$nvim_version" "$download_dir" "$arch_type"
fi
