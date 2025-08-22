#!/usr/bin/env bash

# Compare neovim versions
function is_lesser_version {
	local version1=${1#v}
	local version2=${2#v}

	# Special cases for 'stable' and 'nightly': It is not lesser than any specific version
	if [[ $version1 == "stable" ]] || [[ $version1 == "nightly" ]]; then
		# If version1 is 'stable' or 'nightly', it is not lesser than any specific version
		return 1
	fi

	# Split version numbers into arrays
	IFS='.' read -r -a ver1 <<<"$version1"
	IFS='.' read -r -a ver2 <<<"$version2"

	debug "Checking if version $version1 is lesser than $version2"
	# Compare each part of the version numbers
	for ((i = 0; i < ${#ver1[@]}; i++)); do
		if [[ -z ${ver2[i]} ]]; then
			# If version2 has fewer parts and the current part of version1 is greater than zero
			if ((ver1[i] > 0)); then
				return 1
			fi
		elif ((ver1[i] > ver2[i])); then
			return 1
		elif ((ver1[i] < ver2[i])); then
			return 0
		fi
	done

	# If version2 has more parts and they are greater than zero
	for ((i = ${#ver1[@]}; i < ${#ver2[@]}; i++)); do
		if ((ver2[i] > 0)); then
			return 0
		fi
	done

	return 1
}

function _linux_asset_name {
	# If version is less than 0.10.4, there is no architecture in the download URL
	# else it has to be added into the URL suffix.
	local version="$1" arch_type="$2"
	local asset_name="nvim-linux-${arch_type}.appimage"

	info "Determining asset name for Neovim version $version on Linux with architecture $arch_type"
	local is_lesser
	is_lesser_version "$version" v0.10.4
	is_lesser=$?

	if [[ $is_lesser -eq 0 ]]; then
		asset_name="nvim.appimage"
	fi
	echo "$asset_name"
}

function _macos_asset_name {
	# If version is less than 0.10.0, there is no architecture in the download URL
	# else it has to be added into the URL suffix.
	local version="$1" arch_type="$2"
	local asset_name="nvim-macos-${arch_type}.tar.gz"

	local is_lesser
	is_lesser_version "$version" v0.10.0
	is_lesser=$?

	if [[ $is_lesser -eq 0 ]]; then
		asset_name="nvim-macos.tar.gz"
	fi
	echo "$asset_name"
}

function _get_asset_name {
	local version="$1" os="$2" arch_type="$3"

	local asset_name
	if [[ $os == "Linux" ]]; then
		asset_name=$(_linux_asset_name "$version" "$arch_type")
	elif [[ $os == "Darwin" ]]; then
		asset_name=$(_macos_asset_name "$version" "$arch_type")
	else
		fatal --status=3 "Unsupported OS: $os"
	fi

	debug "Asset name for ${os} ${arch_type} version ${version}: ${asset_name}"
	echo "$asset_name"
}

# Get release download URL based on OS, Arch type and version
function build_github_uri {
	local VERSION=$1 OS=$2 ARCH_TYPE=$3

	local BASE_GITHUB_URI_PATH="https://github.com/neovim/neovim/releases/download/${VERSION}"

	local ASSET_NAME
	ASSET_NAME=$(_get_asset_name "$VERSION" "$OS" "$ARCH_TYPE")

	echo "${BASE_GITHUB_URI_PATH}/${ASSET_NAME}"
}

function _find_sha256_for_version {
	local url="$1"
	local release_json
	release_json=$(cat)
	local digest

	digest=$(printf '%s' "$release_json" | tr -d '\n' | tr '{}' '\n' | grep "\"browser_download_url\"[[:space:]]*:[[:space:]]*\"$url\"" | grep -o 'digest"[[:space:]]*:[[:space:]]*"[^"]*' | grep -o '[^"]*$' | awk -F'sha256:' '{print $2}')

	if [ -n "$digest" ]; then
		debug "SHA256 digest found for $url: $digest"
	else
		debug "No SHA256 digest found for $url"
	fi

	echo "$digest"
}

function get_sha256 {
	local VERSION=$1 OS=$2 ARCH_TYPE=$3

	local DOWNLOAD_URI
	DOWNLOAD_URI=$(build_github_uri "$VERSION" "$OS" "$ARCH_TYPE")

	local older_than_v0_11 older_than_v0_11_3
	is_lesser_version "$VERSION" v0.11.0
	older_than_v0_11=$?
	is_lesser_version "$VERSION" v0.11.3
	older_than_v0_11_3=$?

	local SHA256_URI
	local SHA256_SUM
	if [[ $older_than_v0_11 -eq 0 ]]; then
		info "Neovim version $VERSION is less than 0.11.0, using legacy checksum file"

		SHA256_URI="${DOWNLOAD_URI}.sha256sum"
		SHA256_SUM=$(run_api_call "$SHA256_URI")

		SHA256_SUM=$(printf '%s\n' "$SHA256_SUM" | awk '{print $1}')
	elif [[ $older_than_v0_11_3 -eq 0 ]]; then
		info "Neovim version $VERSION is greater than 0.10 but less than 0.11.3, using shasum.txt file"
		local base_path release_name
		base_path=$(dirname "$DOWNLOAD_URI")
		release_name=$(basename "$DOWNLOAD_URI")
		SHA256_URI="$base_path/shasum.txt"
		SHA256_SUM=$(run_api_call "$SHA256_URI")

		SHA256_SUM=$(printf '%s\n' "$SHA256_SUM" | grep "$release_name" | grep -v "zsync" | awk '{print $1}')
	else
		info "Neovim version $VERSION is greater than or equal to 0.11.3, using GitHub's checksum API"

		SHA256_URI="https://api.github.com/repos/neovim/neovim/releases/tags/${VERSION}"
		debug "Downloading SHA256 from $SHA256_URI"

		local response
		response=$(run_api_call "$SHA256_URI")
		debug "Response from GitHub API: $response"

		SHA256_SUM=$(printf '%s\n' "$response" | _find_sha256_for_version "$DOWNLOAD_URI")
	fi

	if [[ -z $SHA256_SUM ]]; then
		fatal --status=3 "Failed to retrieve SHA256 sum for release item $DOWNLOAD_URI"
	fi

	debug "SHA256 sum: $SHA256_SUM for release item $DOWNLOAD_URI"
	echo "$SHA256_SUM"
}
