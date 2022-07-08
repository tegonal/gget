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
#  internal utility functions for dealing with the pulled file
#  no backward compatibility guarantees or whatsoever
#
###################################

set -eu

function setEntryVariables() {
	# shellcheck disable=SC2034
	IFS=- read -r entryTag entryFile entrySha entryRelativePath <<< "$1"
}

function grepPulledEntryByFile() {
	local pulledFiles=$1
	local file=$2
	shift 2
	grep -E "^[^\t]+	$file" "$@" "$pulledFiles"
}

function replacePulledEntry() {
	local pulledFiles=$1
	local file=$2
	local entry=$3
	shift 3
	grepPulledEntryByFile "$file" "$pulledFiles" -v >"$pulledFiles.new"
	mv "$pulledFiles.new" "$pulledFiles"
	echo "$entry" >>"$pulledFiles"
}
