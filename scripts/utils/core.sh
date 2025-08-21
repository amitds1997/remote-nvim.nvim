#!/usr/bin/env bash

RESET=$'\033[0m'
RED=$'\033[0;31m'
YELLOW=$'\033[0;33m'
CYAN=$'\033[0;36m'
GRAY=$'\033[2;37m'

LOG_LEVELS=("DEBUG" "INFO" "WARN" "ERROR" "FATAL")
LOG_LEVEL_INDEX=1

STACK_TRACE_SENTINEL_FILE=$(mktemp -t trace_remote_nvim_sentinel.XXXXXX)
export STACK_TRACE_SENTINEL_FILE

function set_log_level {
	local level="${1:-INFO}"
	level=$(echo "$level" | tr '[:lower:]' '[:upper:]') # Convert to uppercase
	for i in "${!LOG_LEVELS[@]}"; do
		if [[ ${LOG_LEVELS[$i]} == "$level" ]]; then
			LOG_LEVEL_INDEX=$i
			return 0
		fi
	done
	echo "Unknown log level: $level" >&2
	return 1
}

function _should_log {
	local level="$1"
	for i in "${!LOG_LEVELS[@]}"; do
		if [[ ${LOG_LEVELS[$i]} == "$level" ]]; then
			[[ $i -ge $LOG_LEVEL_INDEX ]] && return 0 || return 1
		fi
	done
	return 1
}

function _print_stack_trace {
	if [[ -s $STACK_TRACE_SENTINEL_FILE ]]; then
		return
	fi

	[[ -n ${STACK_TRACE_SENTINEL_FILE:-} ]] && touch "$STACK_TRACE_SENTINEL_FILE"

	local i=0
	local line_no function_name file_name
	local msg=""
	local skip_functions=("fatal" "_print_stack_trace")

	msg+="\nStack Trace (most recent call first):"

	while true; do
		local caller_output
		caller_output=$(caller "$i") || break

		read -r line_no function_name file_name <<<"$caller_output"

		[[ -z $function_name ]] && function_name="top_level"
		[[ -z $file_name ]] && file_name="unknown_file"

		if [[ " ${skip_functions[*]} " == *" $function_name "* ]]; then
			((i++))
			continue
		fi

		msg+="\n\t${file_name}:${line_no}\t${function_name}"
		((i++))
	done

	echo "$msg" >"$STACK_TRACE_SENTINEL_FILE"
	echo "$msg"
}

function log {
	local LEVEL="$1"
	shift
	STRING=$(printf '%s\n' "$*" | tr -s '[:space:]' ' ')

	set +o nounset
	local TIMESTAMPS="${CONFIG[TIMESTAMPS]:-1}"
	local LOGLEVELS="${CONFIG[LOGLEVELS]:-1}"
	local COLOR="${CONFIG[COLOR]:-1}"
	set -o nounset

	case "$LEVEL" in
	DEBUG) ANSI="$GRAY" ;;
	INFO) ANSI="$CYAN" ;;
	WARN) ANSI="$YELLOW" ;;
	ERROR) ANSI="$RED" ;;
	FATAL) ANSI="$RED" ;;
	*) ANSI="" ;;
	esac

	if _should_log "${LEVEL}"; then
		if [[ $TIMESTAMPS == "1" ]]; then
			TS="[$(date +"%Y-%m-%d %H:%M")] "
		else
			TS=""
		fi

		if [[ $LOGLEVELS == "1" ]]; then
			LEVEL_STR="$(printf '%-7s' "[${LEVEL}] ")"
		else
			LEVEL_STR=""
		fi

		# if COLOR=0 or stderr is not a tty, turn off log coloring
		if [[ $COLOR == "1" && -t 2 ]]; then
			if [[ $LEVEL == "FATAL" ]]; then
				printf '%s%s%s%s%s%b\n' "$GRAY" "$TS" "$ANSI" "$LEVEL_STR" "$RESET" "$STRING" >&2
			else
				printf '%s%s%s%s%s%s\n' "$GRAY" "$TS" "$ANSI" "$LEVEL_STR" "$RESET" "$STRING" >&2
			fi
		else
			if [[ $LEVEL == "FATAL" ]]; then
				printf '%s%s%b\n' "$TS" "$LEVEL_STR" "$STRING" >&2
			else
				# No color, just print the message
				printf '%s%s%b\n' "$TS" "$LEVEL_STR" "$STRING" >&2
			fi
		fi
	fi
}

function debug {
	set +o nounset
	local VERBOSE="${CONFIG[VERBOSE]:-1}"
	set -o nounset

	[[ $VERBOSE != "1" ]] && return 0
	log DEBUG "$*"
}

function info {
	set +o nounset
	local QUIET="${CONFIG[QUIET]:-0}"
	set -o nounset

	[[ $QUIET == "1" ]] && return 0
	log INFO "$*"
}

function warn {
	log WARN "$*"
}

function error {
	log ERROR "$*"
}

function fatal {
	local STATUS=$? MSG=""

	while (("$#")); do
		case "$1" in
		--status | --status=*)
			if [[ $1 == *'='* ]]; then
				STATUS=${1#*=}
			else
				shift
				STATUS=$1
			fi
			shift
			;;
		*)
			MSG="$MSG$1 "
			shift
			;;
		esac
	done

	local stack_trace
	stack_trace=$(_print_stack_trace)
	if [[ -n $stack_trace ]]; then
		MSG="$MSG\n$stack_trace"
	fi
	log FATAL "$MSG"

	# e.g. if STATUS is a named signal like SIGSEV instead of a number
	[ -n "${STATUS##*[!0-9]*}" ] || STATUS=3

	# kill all child processes in current subshell
	jobs -p | xargs 'kill -9 --' 2>/dev/null

	exit "$STATUS"
}
