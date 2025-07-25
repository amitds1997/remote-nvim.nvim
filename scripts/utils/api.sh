#!/usr/bin/env bash

function _get_available_downloader {
	if command -v curl &>/dev/null; then
		echo "curl"
	elif command -v wget &>/dev/null; then
		echo "wget"
	else
		echo "none"
	fi
}

# Download a file from a URL using either curl or wget
# If neither is available, it will exit with an error.
# Usage: download_file <URL> <output_file>
# Example: download_file "https://example.com/file.txt" "file.txt"
function download_file {
	local URL="$1" OUTPUT_FILE="$2"
	if command -v curl &>/dev/null; then
		safe_subshell curl -fsSL -o "$OUTPUT_FILE" "$URL"
		debug "Downloaded file from $URL to $OUTPUT_FILE using cURL"
	elif command -v wget &>/dev/null; then
		safe_subshell wget --quiet --output-document="$OUTPUT_FILE" "$URL"
		debug "Downloaded file from $URL to $OUTPUT_FILE using wget"
	else
		fatal --status=3 "No downloader found. Current options are cURL and wget"
	fi
}

# Run an API call to a given URL and return the response
# Usage: run_api_call <URL>
# Example: run_api_call "https://api.example.com/data"
# This function will use the available downloader (cURL or wget) to fetch the data.
# If neither is available, it will exit with an error.
# It will return the response as a string.
function run_api_call {
	local URL="$1"

	local downloader
	downloader=$(safe_subshell _get_available_downloader)
	if [[ $downloader == "none" ]]; then
		fatal --status=3 "No downloader found. Available options are cURL and wget"
	fi

	local tmpfile
	tmpfile="$(safe_subshell mktemp)"

	safe_subshell download_file "$URL" "$tmpfile"
	local response
	response=$(<"$tmpfile")
	rm -f "$tmpfile"

	debug "API call to $URL returned response: $response"
	echo "$response"
}
