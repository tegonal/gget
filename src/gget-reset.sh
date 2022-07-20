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
#  'reset' command of gget: utility to reset (re-initialise gpg, pull files) for all or one previously defined remote
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#
#    # resets all defined remotes, which means for each remote in .gget
#    # - re-initialise gpg trust based on public keys defined in .gget/remotes/<remote>/public-keys/*.asc
#    # - pull files defined in .gget/remotes/<remote>/pulledTsv
#    gget reset
#
#    # resets the remote tegonal-scripts which means:
#    # - re-initialise gpg trust based on public keys defined in .gget/remotes/tegonal-scripts/public-keys/*.asc
#    # - pull files defined in .gget/remotes/tegonal-scripts/pulledTsv
#    gget reset -r tegonal-scripts
#
#    # uses a custom working directory and resets the remote tegonal-scripts which means:
#    # - re-initialise gpg trust based on public keys defined in .github/.gget/remotes/tegonal-scripts/public-keys/*.asc
#    # - pull files defined in .github/.gget/remotes/tegonal-scripts/pulledTsv
#    gget reset -r tegonal-scripts -w .github/.gget
#
###################################
set -euo pipefail
export -x GGET_VERSION='v0.2.0-SNAPSHOT'

if ! [[ -v dir_of_gget ]]; then
	dir_of_gget="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)"
	declare -r dir_of_gget
fi

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(realpath "$dir_of_gget/../lib/tegonal-scripts/src")"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_gget/pulled-utils.sh"
sourceOnce "$dir_of_gget/utils.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/gpg-utils.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/log.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-args.sh"

function gget-reset() {
	source "$dir_of_gget/shared-patterns.source.sh"

	local currentDir
	currentDir=$(pwd)
	local -r currentDir

	local remote workingDir autoTrust
	# shellcheck disable=SC2034
	local -ar params=(
		remote "$remotePattern" '(optional) if set, only the remote with this name is reset, otherwise all are reset'
		workingDir "$workingDirPattern" "$workingDirParamDocu"
		autoTrust "$autoTrustPattern" "$autoTrustParamDocu"
	)
	local -r examples=$(
		cat <<-EOM
			# reset the remote tegonal-scripts
			gget reset -r tegonal-scripts

			# resets all remotes
			gget reset

			# resets all remotes and imports gpg keys without manual consent
			gget reset --auto-trust true
		EOM
	)

	parseArguments params "$examples" "$GGET_VERSION" "$@"
	if ! [ -v remote ]; then remote=""; fi
	if ! [ -v workingDir ]; then workingDir="$defaultWorkingDir"; fi
	if ! [ -v autoTrust ]; then autoTrust=false; fi
	checkAllArgumentsSet params "$examples" "$GGET_VERSION"

	checkWorkingDirExists "$workingDir"

	function gget-reset-resetRemote() {
		local -r remote=$1
		local remoteDir publicKeysDir repo gpgDir pulledTsv
		source "$dir_of_gget/paths.source.sh"
		rm -r "$gpgDir"
		while read entry; do
			local entryTag entryFile entryRelativePath
			setEntryVariables "$entry"

			set +e
			"$scriptDir/gget-pull.sh" -r "$remote" -t "$entryTag" -p "$entryFile" -d
			set -e
			if (($? == 0)); then

			fi
		done <"$pulledTsv"
	}

	if [ -n "$remote" ]; then
		gget-reset-resetRemote "$remote"
	else
		"$scriptDir/gget-remote.sh" list -w "$workingDir" | gget-reset-resetRemote
	fi
}

gget-reset "$@"
