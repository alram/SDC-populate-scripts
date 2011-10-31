#!/bin/bash

#
# Create dummy users in SDC
# Usage:
#  ./createUsers.sh <number>
#  Where number is the number of users to create
# 
# After executing this script, you can lauch createSMs.sh
#

NB_USERS=$1
if [ -z $NB_USERS ]
then
	echo "Usage: "
	echo " ./createUsers.sh <number>"
	echo " Where number is the number of users to create"
	exit 1
fi

###############################################
#  						Change accordingly							#
###############################################
# Cred & hosts infos for CAPI
ADMIN="admin"
PASS="password"
CAPI="10.99.99.11:8080"
#Timeout for `curl` requests is 10 secs
TIMEOUT="10"
# Log file
LOG_FILE="./output_createUsers.log"
echo "" > $LOG_FILE
#SSH Pub Key file location
KEY_FILE="${HOME}/.ssh/id_rsa.pub"
# Used for usernames when generating clients
DICTIONARY="./propernames"
DATACENTER_NAME="PAR1FR"
RAISE_LIMIT_TO="5"
###############################################
###############################################
###############################################


#
# Get the max clients that is possible to create
# (= number of names in the dict)
#
function maxClient {
	MAX_CLIENTS=`wc -l $DICTIONARY | awk '{print $1}'`
	if [ $NB_USERS -gt $MAX_CLIENTS ]
	then
		NB_USERS=$MAX_CLIENTS;
		echo -e "Cannot create more than $MAX_CLIENTS clients due to dictionary limitations.\nNumber of clients to generate has been set to $NB_USERS."
	fi
}

#
# Verify that there is a key file in the default location
# Edit KEY_FILE if necessary
#
function verifyKeys {
	if [ ! -f $KEY_FILE ]
	then
		echo "Your RSA Public Key cannot be found in $KEY_FILE"
    echo "Edit the KEY_FILE variable and/or create a new key using:"
    echo " ssh-keygen -t rsa"
    exit 1
	fi
}

#
# This where the job is done
# Create NB_USERS thanks to CAPI
#
function createUsers {
	i=1
	while [ $i -le $NB_USERS ]
	do
		#Get ith line from the dictionnary and lower case it
		name=`sed -n "${i}"p $DICTIONARY|tr '[A-Z]' '[a-z]'`
		echo "[`date "+%y-%m-%d|%H:%M:%S"`] -----------Creating user ${name}-------------" >> ${LOG_FILE}
		#Do the request 
		ERROR=`curl -is -u ${ADMIN}:${PASS} --connect-timeout ${TIMEOUT} -H "Accept:application/json" --url http://${CAPI}/customers -X POST -d customer='{"login":"'${name}'","email_address":"'${name}'@local.lan","password":"secret","password_confirmation":"secret"}' | tee -a ${LOG_FILE} | grep errors`
		echo "[`date "+%y-%m-%d|%H:%M:%S"`] ------------------------------------------------------------------------------------"
		if [ -n "$ERROR" ];
		then
			echo "[`date "+%y-%m-%d|%H:%M:%S"`] Creating user number $i: $name - NOT OK - $ERROR"
		else
			echo "[`date "+%y-%m-%d|%H:%M:%S"`] Creating user number $i: $name - OK"
			# Add the RSA PUB KEY to the user and raise default provisionning limit
      addKey
			raiseLimits
		fi
		echo -e "\n[`date "+%y-%m-%d|%H:%M:%S"`] -----------End Creating user ${name}-------------" >> ${LOG_FILE}
		i=`expr $i + 1`
	done
}

#
# Add the ssh rsa pub key to the customer
# so we can provision with the createSMs.sh script
#
function addKey {
	RSA_KEY=`cat ${KEY_FILE}`
  ERROR=`curl -is -u ${ADMIN}:${PASS} --connect-timeout ${TIMEOUT} -H "Accept:application/json" --url http://${CAPI}/customers/${name}/keys -F key="${RSA_KEY}" -F name=pubkey -X POST | tee -a ${LOG_FILE} | grep errors`
	if [ -n "$ERROR" ]
	then
		echo "[`date "+%y-%m-%d|%H:%M:%S"`] Adding SSH RSA Public Key to user $name - NOT OK - $ERROR"
	else
		echo "[`date "+%y-%m-%d|%H:%M:%S"`] Adding SSH RSA Public Key to user $name - OK"
	fi
}

#
# Default limit is set to 1 machine type / DC
# We raise that to RAISE_LIMIT_TO for smartos type machines
#
function raiseLimits {
	ERROR=`curl -is -u ${ADMIN}:${PASS} --connect-timeout ${TIMEOUT} -H "Accept:application/json" --url http://${CAPI}/customers/${name}/limits/${DATACENTER_NAME}/smartos -d ${RAISE_LIMIT_TO} -X PUT | tee -a ${LOG_FILE} | grep errors`
	if [ -n "$ERROR" ]
	then
		echo "[`date "+%y-%m-%d|%H:%M:%S"`] Raising limit of $name in ${DATACENTER_NAME} to ${RAISE_LIMIT_TO} SmartOS SmartMachines - NOT OK"
	else
		echo "[`date "+%y-%m-%d|%H:%M:%S"`] Raising limit of $name in ${DATACENTER_NAME} to ${RAISE_LIMIT_TO} SmartOS SmartMachines - OK"
	fi
	echo "[`date "+%y-%m-%d|%H:%M:%S"`] ------------------------------------------------------------------------------------"
}

#Call the functions
verifyKeys
maxClient
#createUsers
exit 0