#!/bin/bash -u


bindir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

. ${bindir}/toolsLib.source


function printUsage() {
	commandName=$(basename "$0")
	errecho ""
	errecho "Usage: "
	errecho ""
	errecho "	$commandName -l <localFilePathToEdit> [<user>@]host1[:<remotePath>] [ [<user>@]host2[:<remotePath>] ] ..."
	errecho ""
	errecho "		      this mode will launch sublime editor on local copy "
	errecho "               then replicate automatically through rcp copies any change detected on local file to all remote hosts"
	errecho ""
	errecho "	$commandName -r [<user>@]host1:<remotePath> [ [<user>@]host2[:<remotePath>] ] ..."
	errecho ""
	errecho "		      this mode will retrieve file from first host, launch sublime editor on local copy, "
	errecho "               then replicate automatically through rcp copies any change detected on local file to all remote hosts."
	errecho ""
}

function ctrl_c() {
	log "End of remote edition for file '${remoteFile}'."
	rm -rf "${tmpdir}"
	exit 0
}



remoteMode=${1:-}

case $remoteMode in
	-l)
		mode=local
		if [ $# -lt 3 ] ; then
			printUsage
			fatal "Not enough parameters for -l mode."
		fi
		localFile=$2
		referencePath=$(absolutePath "$localFile")
		lastpart=$(basename ${localFile})
		shift 2
		;;
	-r)
		mode=remote
		if [ $# -lt 2 ] ; then
			printUsage
			fatal "Not enough parameters for -r mode."
		fi
		# remote file should be with RCP syntax : [user]@host:path
		firstRemoteFile=$2
		referencePath=${firstRemoteFile##*:}
		if [ "${referencePath}" == "${firstRemoteFile}" ] || [ "${referencePath}" == "" ] ; then
			printUsage
			fatal "for -r mode, remote path must be provided for first remote host."
		fi
		firstRemoteHost=${firstRemoteFile%%:*}
		tmpdir=$(mktemp -d ${firstRemoteHost}-XXXXXX )
		lastpart=$(basename "${referencePath}")
		localFile=${tmpdir}/${lastpart}
		trap ctrl_c INT 
		shift
		;;
	*)
		printUsage
		fatal "One of '-r' or '-l' modes must be provided as first parameter"
		;;
esac


nbRemote=0

log ""
log "Updates will have to be dispatched to :"
log "---------------------------------------"

while [ $# -gt 0 ] ; do
	remoteFile=$1
	remotePath=${remoteFile##*:}
	#if remoteFile path is not provided, use the same as reference path
	if [ "${remotePath}" == "${remoteFile}" ] ; then 
		# the ':' is not there
		remoteFile=${remoteFile}:${referencePath}
	elif [ "${remotePath}" == "" ] ; then
		# the ':' is there, with nothing behind
		remoteFile=${remoteFile}${referencePath}
	fi
	log "  ${remoteFile}"
	remoteFiles[${nbRemote}]=${remoteFile}
	shift
	let nbRemote=nbRemote+1
done


log ""
log "Checking access to remote hosts..."
log "----------------------------------"
for file in ${remoteFiles[@]} ; do
	remoteHost=${file%%:*}
	waitForSshSuccess ${remoteHost} || fatal "Cannot remote edit"	
done


log ""
if [ $mode == remote ]; then
	log "Starting edit and dispatch on file '$firstRemoteFile' ; local temporary copy is in ${tmpdir}..."
	rcp "${firstRemoteFile}" "${localFile}" || ( touch "${localFile}" && warn "This is a new file" )
else
	log "Starting edit and dispatch on local file '${localFile}'..."
fi
log ""

if ! [ -f "${localFile}" ] ; then fatal "program error in $0 : file should exist at this step"; fi
subl "${localFile}"


while true; do
	 inotifywait -q -e close_write,moved_to,create "${localFile}" > /dev/null
	 log "File '${lastpart}' has changed."
	 for remoteFile in ${remoteFiles[@]} ; do

	 	log  -n "   Updating '${remoteFile}'..."
	 	( rcp "${localFile}" "${remoteFile}" > /dev/null && echo "Done." ) || error "COULD NOT UPDATE REMOTE FILE '${remoteFile}'."
	 done
	 log "  finished UPDATES at $(date)."
done


