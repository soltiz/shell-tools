#!/bin/bash -u


bindir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

. ${bindir}/toolsLib.source


# remote file should be with RCP syntax : [user]@host:path
remoteFile=$1
remoteHost=${remoteFile%%:*}


waitForSshSuccess ${remoteHost} || fatal "Cannot remote edit"

tmpdir=$(mktemp -d ${remoteHost}-XXXXXX )
lastpart=$(basename ${remoteFile##*:})
localFile=${tmpdir}/${lastpart}


log "Starting remote edit on file '$remoteFile'..."

rcp "${remoteFile}" "${localFile}" || (touch "${localFile}" && warn "This is a new file")

subl "${localFile}"

trap ctrl_c INT 
function ctrl_c() {
	log "End of remote edition for file '${remoteFile}'."
	rm -rf "${tmpdir}"
	exit 0
}

while true; do
	 inotifywait -e close_write,moved_to,create "${localFile}" > /dev/null
	 log -n "File '${lastpart}' has changed. Updating '${remoteFile}'..."
	 rcp "${localFile}" "${remoteFile}" || error "COULD NOT UPDATE REMOTE FILE '${remoteFile}'."
	 log " UPDATED at $(date)."
done


