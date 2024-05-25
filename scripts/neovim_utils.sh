#!/usr/bin/env bash

# Compare neovim versions
function compare_versions() {

	local version1=${1#v}
	local version2=${2#v}

	# Split version numbers into arrays
	IFS='.' read -r -a ver1 <<<"$version1"
	IFS='.' read -r -a ver2 <<<"$version2"

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
			return 2
		fi
	done

	# If version2 has more parts and they are greater than zero
	for ((i = ${#ver1[@]}; i < ${#ver2[@]}; i++)); do
		if ((ver2[i] > 0)); then
			return 2
		fi
	done

	return 0
}
