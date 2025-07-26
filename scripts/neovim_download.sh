#!/usr/bin/env bash

# If anything fails, exit
set -eouE pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# shellcheck source=SCRIPTDIR/utils/core.sh
source "${SCRIPTS_DIR}/utils/core.sh"
# shellcheck source=SCRIPTDIR/utils/api.sh
source "${SCRIPTS_DIR}/utils/api.sh"
# shellcheck source=SCRIPTDIR/utils/neovim.sh
source "${SCRIPTS_DIR}/utils/neovim.sh"

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

function download_neovim() {
	local os="$1" version="$2" download_dir="$3" arch_type="$4"

	local download_url, download_path, checksum_path, expected_checksum, actual_checksum
	download_url=$(safe_subshell build_github_uri "$version" "$os" "$arch_type")
	download_path="$download_dir/$(basename "$download_url")"

	checksum_path="$download_path".sha256sum
	actual_checksum="$expected_checksum-actual" # This ensures that they do not match
	expected_checksum=$(safe_subshell get_sha256 "$version" "$os" "$arch_type")

	if [ -e "$download_path" ] && [ -e "$checksum_path" ]; then
		expected_checksum=$(<"$checksum_path")
		actual_checksum=$(sha256sum "$download_path" | cut -d ' ' -f 1)
	fi

	if [ "$actual_checksum" == "$expected_checksum" ]; then
		info "Existing installation with matching checksum found. Skipping downloading..."
		return 0
	fi

	download_file "$download_url" "$download_path"
	info "Downloaded Neovim release ${version} for ${os} (${arch_type}) to ${download_path}"
}

# Download Neovim source
function download_neovim_source() {
	local version="$1"
	local download_dir="$2"
	local download_url="https://github.com/neovim/neovim/archive/refs/tags/${version}.tar.gz"
	local download_path="${download_dir}/nvim-${version}-source.tar.gz"

	debug "Downloading Neovim source..."
	download_file "$download_url" "$download_path"

	info "Downloaded Neovim source version ${version} to ${download_path}"
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
	error "Missing options. Use -h to see the usage."
	exit 1
fi

if [[ $download_dir == *"remote-nvim.nvim/version_cache"* ]]; then
	info "$download_dir is the default path. So, recursively creating the necessary directories"
	mkdir -p "$download_dir"
fi

if [[ ! -d $download_dir ]]; then
	info "$download_dir does not exist. Will try creating it now.."
	if ! mkdir "$download_dir"; then
		error "$download_dir creation failed as parent directories do not exist"
		exit 1
	else
		info "Created $download_dir successfully"
	fi
fi

if [[ $nvim_version != "stable" && $nvim_version != "nightly" && ! $nvim_version =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	error "Invalid Neovim version: $nvim_version"
	exit 1
fi

if [[ $download_type == "source" ]]; then
	download_neovim_source "$nvim_version" "$download_dir"
elif [[ $download_type == "system" ]]; then
	error "Cannot download a system-type Neovim release. Choose from either 'source' or 'binary'."
	exit 1
else
	download_neovim "$os_name" "$nvim_version" "$download_dir" "$arch_type"
fi
