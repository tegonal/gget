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
#  'remote' command of gget: utlity to manage gget remotes
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#
#    # adds the remote tegonal-scripts with url https://github.com/tegonal/scripts
#    gget remote add -r tegonal-scripts -u https://github.com/tegonal/scripts
#
#    # lists all existing remotes
#    gget remote list
#
#    # removes the remote tegonal-scripts again
#    gget remote remove -r tegonal-scripts
#
###################################

set -eu

function gget-remote() {

	local scriptDir
	scriptDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)"
	local -r scriptDir
	local currentDir
	currentDir=$(pwd)
	local -r currentDir

	source "$scriptDir/shared-patterns.source.sh"
	source "$scriptDir/gpg-utils.sh"
	source "$scriptDir/utils.sh"
	source "$scriptDir/../lib/tegonal-scripts/src/utility/parse-args.sh" || exit 200

	function add() {

		local remote url pullDirectory workingDirectory unsecure
		# shellcheck disable=SC2034
		local -ra params=(
			remote "$REMOTE_PATTERN" 'name to refer to this the remote repository'
			url '-u|--url' 'url of the remote repository'
			pullDirectory "$PULL_DIR_PATTERN" '(optional) directory into which files are pulled -- default: lib/<remote>'
			unsecure "$UNSECURE_PATTERN" "(optional) if set to true, the remote does not need to have GPG key(s) defined at $DEFAULT_WORKING_DIR/*.asc -- default: false"
			workingDirectory "$WORKING_DIR_PATTERN" "(optional) path which gget shall use as working directory -- default: $DEFAULT_WORKING_DIR"
		)
		local -r examples=$(
			cat <<-EOM
				# adds the remote tegonal-scripts with url https://github.com/tegonal/scripts
				# uses the default location lib/tegonal-scripts for the files which will be pulled from this remote
				gget remote add -r tegonal-scripts -u https://github.com/tegonal/scripts

				# uses a custom pull directory, files of the remote tegonal-scripts will now
				# be placed into scripts/lib/tegonal-scripts instead of default location lib/tegonal-scripts
				gget remote add -r tegonal-scripts -u https://github.com/tegonal/scripts -d scripts/lib/tegonal-scripts

				# Does not complain if the remote does not provide a GPG key for verification (but still tries to fetch one)
				gget remote add -r tegonal-scripts -u https://github.com/tegonal/scripts --unsecure true

				# uses a custom working directory
				gget remote add -r tegonal-scripts -u https://github.com/tegonal/scripts -w .github/.gget
			EOM
		)
		parseArguments params "$examples" "$@"
		if ! [ -v pullDirectory ]; then pullDirectory="lib/$remote"; fi
		if ! [ -v unsecure ]; then unsecure=false; fi
		if ! [ -v workingDirectory ]; then workingDirectory="$DEFAULT_WORKING_DIR"; fi
		checkAllArgumentsSet params "$examples"

		# make directory paths absolute
		local -r workingDirectory=$(readlink -m "$workingDirectory")

		mkdir -p "$workingDirectory/remotes"

		local remoteDirectory publicKeys repo gpgDir
		source "$scriptDir/directories.source.sh"

		if [ -f "$remoteDirectory" ]; then
			printf >&2 "\033[1;31mERROR\033[0m: cannot create remote directory, there is a file at this location: %s\n" "$remoteDirectory"
			exit 9
		elif [ -d "$remoteDirectory" ]; then
			printf >&2 "\033[1;31mERROR\033[0m: remote \033[0;36m%s\033[0m already exists, remove with: gget remote remove %s\n" "$remote" "$remote"
			exit 9
		fi

		mkdir "$remoteDirectory" || (printf >&2 "\033[1;31mERROR\033[0m: failed to create remote directory %s\n" "$remoteDirectory" && exit 1)
		echo "--directory \"$pullDirectory\"" >"$remoteDirectory/pull.args"

		mkdir "$publicKeys"
		mkdir "$repo"
		mkdir "$gpgDir"
		chmod 700 "$gpgDir"

		cd "$repo"

		# show commands in output
		set -x
		git init
		git remote add "$remote" "$url"

		cd "$currentDir"
		# we need to copy the git config away in order that one can commit it
		# this file will be used to restore the config for those who have not setup the remote on their machine
		cp "$repo/.git/config" "$remoteDirectory/gitconfig"

		cd "$repo"
		defaultBranch="$(git remote show "$remote" | sed -n '/HEAD branch/s/.*: //p')"

		git fetch --depth 1 "$remote" "$defaultBranch"

		# don't show commands in output anymore
		{ set +x; } 2>/dev/null

		set +e
		git checkout "$remote/$defaultBranch" -- '.gget'
		set -e
		local -ri checkoutResult=$?

		if ! ((checkoutResult == 0)); then
			if [ "$unsecure" == true ]; then
				printf "\033[1;33mWARNING\033[0m: no GPG key found, ignoring it because %s true was specified\n" "$UNSECURE_PATTERN"
				echo "$UNSECURE_PATTERN true" >>"$workingDirectory/pull.args"
				exit 0
			else
				printf >&2 "\033[1;31mERROR\033[0m: remote \033[0;36m%s\033[0m has no directory \033[0;36m.gget\033[0m defined in branch \033[0;36m%s\033[0m, unable to fetch the GPG key(s)\n" "$remote" "$defaultBranch"
				deleteDirChmod777 "$remoteDirectory"
				exit 1
			fi
		fi

		# shellcheck disable=SC2310,SC2311
		if noAscInDir "$repo/.gget"; then
			printf >&2 "\033[1;31mERROR\033[0m: remote \033[0;36m%s\033[0m has a directory \033[0;36m.gget\033[0m but no GPG key ending in *.asc defined in it\n" "$remote"
			deleteDirChmod777 "$remoteDirectory"
			exit 1
		fi

		local -i numberOfImportedKeys=0

		local tmpFile
		tmpFile=$(mktemp /tmp/gget.XXXXXXXXX)
		exec 3>"$tmpFile"
		exec 4<"$tmpFile"
		rm "$tmpFile"

		findAsc "$repo/.gget" -print0 >&3

		echo ""
		while read -u 4 -r -d $'\0' file; do
			# shellcheck disable=SC2310
			if importKey "$gpgDir" "$file" --confirm=true; then
				mv "$file" "$publicKeys/"
				((numberOfImportedKeys += 1))
			else
				echo "deleting key $file"
				rm "$file"
			fi
		done
		exec 3>&-
		exec 4<&-
		deleteDirChmod777 "$repo/.gget"

		if ((numberOfImportedKeys == 0)); then
			if [ "$unsecure" == true ]; then
				printf "\033[1;33mWARNING\033[0m: no GPG keys imported, ignoring it because %s true was specified\n" "$UNSECURE_PATTERN"
				exit 0
			else
				printf >&2 "\033[1;31mERROR\033[0m: no GPG keys imported, you won't be able to pull files from the remote \033[0;36m%s\033[0m without using %s true\n" "$remote" "$UNSECURE_PATTERN"
				exit 1
			fi
		fi

		gpg --homedir "$gpgDir" --list-sig
		printf "\033[1;32mSUCCESS\033[0m: remote \033[0;36m%s\033[0m was set up successfully; imported %s GPG key(s) for verification.\nYou are ready to pull files via:\ngget pull -r %s -t <VERSION> -p <PATH>\n" "$remote" "$numberOfImportedKeys" "$remote"
	}

	function list() {
		local workingDirectory
		# shellcheck disable=SC2034
		local -ra params=(
			workingDirectory "$WORKING_DIR_PATTERN" '(optional) define a path which gget shall use as working directory -- default: .gget'
		)
		local -r examples=$(
			cat <<-EOM
				# lists all defined remotes in .gget
				gget remote list

				# uses a custom working directory
				gget remote list -w .github/.gget
			EOM
		)

		parseArguments params "$examples" "$@"
		if ! [ -v workingDirectory ]; then workingDirectory="$DEFAULT_WORKING_DIR"; fi
		checkAllArgumentsSet params "$examples"

		checkWorkingDirectoryExists "$workingDirectory"

		local remotesDirectory
		source "$scriptDir/directories.source.sh"

		cd "$remotesDirectory"
		local output
		output="$(find . -maxdepth 1 -type d -not -path "." | cut -c 3-)"
		if [ "$output" == "" ]; then
			printf "\033[1;33mNo remote define yet.\033[0m\n"
			echo "To add one, use: gget remote add ..."
			echo "Following the corresponding documentation of the parameters:"
			add "--help"
		else
			echo "$output"
		fi
	}

	function remove() {
		local workingDirectory
		# shellcheck disable=SC2034
		local -ra params=(
			remote '-r|--remote' 'define the name of the remote which shall be removed'
			workingDirectory "$WORKING_DIR_PATTERN" '(optional) define a path which gget shall use as working directory -- default: .gget'
		)
		local -r examples=$(
			cat <<-EOM
				# removes the remote tegonal-scripts
				gget remote remove -r tegonal-scripts

				# uses a custom working directory
				gget remote remove -r tegonal-scripts -w .github/.gget
			EOM
		)

		parseArguments params "$examples" "$@"
		if ! [ -v workingDirectory ]; then workingDirectory="$DEFAULT_WORKING_DIR"; fi
		checkAllArgumentsSet params "$examples"

		checkWorkingDirectoryExists "$workingDirectory"

		local remoteDirectory
		source "$scriptDir/directories.source.sh"

		if [ -f "$remoteDirectory" ]; then
			printf >&2 "\033[1;31mERROR\033[0m: cannot delete remote \033[0;36m%s\033[0m, looks like it is broken there is a file at this location: %s\n" "$remote" "$remoteDirectory"
			exit 9
		elif ! [ -d "$remoteDirectory" ]; then
			printf >&2 "\033[1;31mERROR\033[0m: remote \033[0;36m%s\033[0m does not exist, check for typos.\nFollowing the remotes which exist:\n" "$remote"
			list -w "$workingDirectory"
			exit 9
		fi

		deleteDirChmod777 "$remoteDirectory"
		printf "\033[1;32mSUCCESS\033[0m: removed remote \033[0;36m%s\033[0m\n" "$remote"
	}

	if [[ $# -lt 1 ]]; then
		printf >&2 "\033[1;31mERROR\033[0m: At least one parameter needs to be passed\nGiven \033[0;36m%s\033[0m in \033[0;36m%s\033[0m\nFollowing a description of the parameters:\n" "$#" "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
		echo >&2 '1. command     one of: add, remove, list'
		echo >&2 '2... args...   command specific arguments'
		exit 9
	fi

	declare command=$1
	shift
	if [[ "$command" =~ ^(add|remove|list)$ ]]; then
		"$command" "$@"
	elif [[ "$command" == "--help" ]]; then
		cat <<-EOM
			Use one of the following commands:
			add      add a remote
			remove   remove a remote
			list     list all existing remotes
		EOM
	else
		printf >&2 "\033[1;31mERROR\033[0m: unknown command %s, expected one of add, list, remove\n" "$command"
		exit 9
	fi
}
gget-remote "$@"
