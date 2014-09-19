#!/bin/bash -u
source commons-lib.sh



# the following function receives a "stdout" prefix string as a parameter 1
# and a "stderr" prefix string as a parameter 1
# other arguments are a command line string to run
# The result is that all outputs (stdout and stderr) are prefixed by the provided prefixes
# WITH stdout still being separated from stderr at the end.
# because sed is used, prefixes cannot contain the sed separator
# by default, this separator is '/' but it can be changed by providing optional
# option '--separator <character>' before first prefix
function prefixCommandOutput(){
	if [ $# -lt 3 ]; then
		error "prefixCommandOutput() takes at least 3 arguments"
		exit 1
	fi
	local sep="/"
	if [ "$1" == "--separator" ]; then
		sep="$2"
		shift 2
	fi
	if [ $# -lt 3 ]; then
		error "prefixCommandOutput() takes at least 3 arguments in addition to '--separator <char>'."
		exit 1
	fi
	
	stdoutPrefix="$1"
	stderrPrefix="$2"
	shift 2
	 ( ( ( eval "$*"  | sed "s${sep}^${sep}${stdoutPrefix}${sep}g" && exit ${PIPESTATUS[0]})  3>&1 1>&2 2>&3 )  | sed "s${sep}^${sep}$stderrPrefix${sep}g" && exit ${PIPESTATUS[0]})  3>&1 1>&2 2>&3 	
	 return $?
}
	
# parallel execution of the same command for several parameters sets
#   parallelExecution [ --names <namesArray variable name> ] -- command line
#   in the command line, any string of the form %<%varname%>' will be substituted by
#   successive values from the shell array which variable name is varname
#   if --names is provided, then the shell array with this name is used as source
#   for identifying the process instances (in output and result status). If this option
# is not present, first substitution variable wil be used instead
function parallelExecution() {
	commandString=$@
	local beginTag="{:::"
	local endTag=":::}"
	
		
	function firstVariableInString() {
		local theString="$1"
		local leftAndVar="${theString%%${endTag}*}" 
		if [ "$leftAndVar" == "$theString" ]; then
			echo ""
		else
			varName="${leftAndVar##*${beginTag}}"
			echo "$varName"
		fi
	}
		
	function getSubstitutedCommand() {
		local argsIndex=$1
		shift
		local 	theCommand="$@"
		
		 
		
		local varName=$(firstVariableInString "$theCommand")
		while [ "$varName" != "" ]; do
			valueRef=$varName[$argsIndex]
			value=${!valueRef}
			local tagSearch="${beginTag}${varName}${endTag}"
			theCommand=${theCommand/${tagSearch}/${value}}
			varName=$(firstVariableInString "$theCommand")
		done
		echo "$theCommand"
	}

	local PIDS=()
	
	
	local nameVar=$(firstVariableInString "$commandString")
	local namesRef=$nameVar[@]
	local names=("${!namesRef}")
	local namesCount=${#names[@]}
	local index
	local lastIndex
	let lastIndex=namesCount-1

	
	for index in $(seq 0 $lastIndex); do
		local instanceName="${names[index]}"
		local commandInstance=$(getSubstitutedCommand $index "$commandString" )
		( prefixCommandOutput "${instanceName}> " "! ${instanceName} 2> " "$commandInstance" ) &
		PIDS+=( $! )
	done

	if ! wait ${PIDS[@]} ; then
		local l=0
		local name
		for name in "${names[@]}"; do
			wait ${PIDS[${l}]}
			local rc=$?
			if [ $rc -ne 0 ]; then
				error --no-context "Execution for '$name' returned '$rc'."
			fi
			let l=l+1
		done
		error "At least one execution failed on command."
		return 1
	fi
	trap "$previousExitTrapCode" SIGINT
	return 0
}


alpha=(un deux trois quatre cinq)
beta=(one two three four five)
wait=(5 4 3 2 1)
parallelExecution "sleep {:::wait:::} ; echo 'traduction de {:::alpha:::} : {:::alpha:::}={:::beta:::}.'"



