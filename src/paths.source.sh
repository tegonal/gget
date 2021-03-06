#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2168,SC2154
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gget
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.2.0-SNAPSHOT
#
#######  Description  #############
#
#  constants intended to be sourced into a function.
#	 Requires that $workingDir is defined beforehand
#
###################################


# note if you change this structure, then you need to adopt gget_pull => pullArgsFile
local -r remotesDir="$workingDir/remotes"
local -r remoteDir="$remotesDir/$remote"
local -r publicKeysDir="$remoteDir/public-keys"
local -r repo="$remoteDir/repo"
local -r gpgDir="$publicKeysDir/gpg"
local -r pulledTsv="$remoteDir/pulled.tsv"
