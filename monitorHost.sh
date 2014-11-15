#!/bin/bash

. commons-lib.sh

TIMEFORMAT="%R"
logdir=logs
mkdir -p $logdir
trap 'kill $(jobs -p)' SIGINT SIGTERM EXIT

function humanCompactDatetime() {
	date +%Y%m%d%H%M%S
}





function monitorHost() {

	host=$1
	user=$2
	checkIntervalInSeconds=15
	let pingTimeout=checkIntervalInSeconds-2

	pingCommand="ping -W $pingTimeout -c 1 $host"
	sshCommand="ssh $user@$host ls"

	log "Starting monitoring of host '$host' - $(date)"
	log "monitoring will use these commands :"
	log "  $pingCommand"

	nextCheckTimeStamp=$(date +%s)

	while true ;do
	 	currentTimeStamp=$(date +%s)
	 	let secondsToSleep=nextCheckTimeStamp-currentTimeStamp
	 	let nextCheckTimeStamp=nextCheckTimeStamp+checkIntervalInSeconds
	 	if [ $secondsToSleep -gt 0 ]; then
	 		sleep $secondsToSleep
	 	fi
	 	echo -n "$(humanCompactDatetime) - "
	 	pingDuration=$(time ( $pingCommand 2>&1 >/dev/null ) 2>&1)
	 	pingRc=$?
	 	echo -n "Ping : ${pingDuration}s rc=$pingRc"
	    sshDuration=$(time ( $sshCommand 2>&1 >/dev/null ) 2>&1)
	 	sshRc=$?
	 	echo  "  Ssh : ${sshDuration}s rc=$sshRc"
	done
}


for host in localvm1 lmcinject lmckaff1 lmckafb1 lmces1; do
	(monitorHost $host ubuntu >> $logdir/$host-monitoring.log 2>&1 )&
done

wait
