#!/bin/bash

#
# deleteSMs.sh : Delete SmartMachines for all users in SDC (except 'admin')
#

###############################################
#  						Change accordingly							#
###############################################
# Creds & hosts infos for CAPI
CAPIADMIN="admin"
CAPIPASS="password"
CAPI="10.99.99.11:8080"
# Creds & hosts infos for CloudAPI
# Each user is provisioned by admin account
CLOUDAPIUSER="admin"
CLOUDAPIPASS="password"
CLOUDAPI="10.88.88.6"
CLOUDAPIVERSION="~6.5"
# Default timeout for requests is 10 secs
TIMEOUT="10"
###############################################
###############################################
###############################################

#
# Get the users list
#
function listUsers {
	for name in `curl -s -u ${CAPIADMIN}:${CAPIPASS} --connect-timeout ${TIMEOUT} -H "Accept:application/xml" --url http://${CAPI}/customers | grep login | sed -n -e 's/login//g' -e 's/[<>/ ]//gp'`
	do
		if [ $name = "admin" ]
		then
			continue
		fi
		# Create the SmartMachines
		getSMsIDbyUser
	done
}

#
# Get all the SmartMachine a user has provisioned
#
function getSMsIDbyUser {
	IDs=`curl -sk -u ${CLOUDAPIUSER}:${CLOUDAPIPASS} --connect-timeout ${TIMEOUT} -H "X-Api-Version: ${CLOUDAPIVERSION}" --url https://${CLOUDAPI}/${name}/machines |grep id | cut -d ':' -f 2 | sed -n 's/[ ",]//gp'`
	echo "[`date "+%y-%m-%d|%H:%M:%S"`] ----------------User ${name}----------------"
	if [ -z "$IDs" ]
	then
		echo "[`date "+%y-%m-%d|%H:%M:%S"`] User ${name} has no machine";
	else
		# Calls machine shutdown
		echo "[`date "+%y-%m-%d|%H:%M:%S"`] User ${name} has machines"
		echo "[`date "+%y-%m-%d|%H:%M:%S"`] Let's delete them..."
		shutdownMachines
	fi
	echo "[`date "+%y-%m-%d|%H:%M:%S"`] -----------End of User ${name}-------------"
}

#
# Try to stop the SmartMachines
#
function shutdownMachines {
	for id in $IDs
	do
		ERROR=`curl -sk -u ${CLOUDAPIUSER}:${CLOUDAPIPASS} --connect-timeout ${TIMEOUT} -H "X-Api-Version: ${CLOUDAPIVERSION}" --url https://${CLOUDAPI}/${name}/machines/${id}?action=stop -X POST | grep message`
		if [ -n "$ERROR" ]
		then
			echo "[`date "+%y-%m-%d|%H:%M:%S"`] Stopping machine ${id} from user ${name} - NOT OK - ${ERROR}"
			# Can't stop the machine -> can't delete it
			IDs=`echo ${IDs} | sed -n "s/${id}//p"`
		else
			echo "[`date "+%y-%m-%d|%H:%M:%S"`] Stopping machine ${id} from user ${name} - OK"
		fi
	done
	deleteMachines
}

#
# Try to delete the SmartMachines
#
function deleteMachines {
	for id in $IDs
	do
		ERROR="InvalidState"
		echo "[`date "+%y-%m-%d|%H:%M:%S"`] Waiting for machine ${id} from user ${name} to stop..."
		# Machine is still started
		while [ "${ERROR}" = "InvalidState" ]
		do
			ERROR=`curl -sk -u ${CLOUDAPIUSER}:${CLOUDAPIPASS} --connect-timeout ${TIMEOUT} -H "X-Api-Version: ${CLOUDAPIVERSION}" --url https://${CLOUDAPI}/${name}/machines/${id} -X DELETE | grep code | cut -d ':' -f2 | sed -n 's/[ ",]//gp'`
		done
		
		if [ -n "$ERROR" ]
		then
			echo "[`date "+%y-%m-%d|%H:%M:%S"`] Deleting machine ${id} from user ${name} - NOT OK - ${ERROR}"
		else
			echo "[`date "+%y-%m-%d|%H:%M:%S"`] Deleting machine ${id} from user ${name} - OK"
		fi
	done
}

listUsers
exit 0