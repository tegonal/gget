#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gget
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.1.0-SNAPSHOT
#
#######  Description  #############
#
#  internal utility functions
#  no backward compatibility guarantees or whatsoever
#
###################################

set -eu

function deleteDirChmod777() {
	local -r dir=$1
	# e.g files in .git will be write-protected and we don't want sudo for this command
	chmod -R 777 "$dir"
	rm -r "$dir"
}

function findAscInDir() {
	local -r dir=$1
	shift
	find "$dir" -maxdepth 1 -type f -name "*.asc" "$@"
}

function noAscInDir() {
	local -r dir=$1
	shift 1
	(($(findAscInDir "$dir" | wc -l) == 0))
}

function checkWorkingDirectoryExists() {
	local workingDirectory=$1

	local scriptDir
	scriptDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)"
	local -r scriptDir
	source "$scriptDir/shared-patterns.source.sh"

	if ! [ -d "$workingDirectory" ]; then
		printf >&2 "\033[1;31mERROR\033[0m: working directory \033[0;36m%s\033[0m does not exist\n" "$workingDirectory"
		echo >&2 "Check for typos and/or use $WORKING_DIR_PATTERN to specify another"
		exit 9
	fi
}
