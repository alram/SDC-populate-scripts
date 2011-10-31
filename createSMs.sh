#!/bin/bash

#
# Create NB_MACHINES SmartMachines for all users in SDC (except 'admin')
# SmartMachines are default ${PACKAGE} bare SmartOS.
#
# Usage:
#  ./createSMs.sh <number>
#  Where number is the number of SM per user to create 
# 
# /!\ Warning : Users may have provisionning limits /!\


NB_MACHINES=$1
if [ -z $NB_MACHINES ]
then
	echo "Usage:"
	echo " ./createSMs.sh <number>"
	echo " Where number is the number of SM/user to create"
	exit 1
fi

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
PACKAGE="regular_1024"
# Default timeout for `curl` requests is 10 secs
TIMEOUT="10"
# Log file
LOG_FILE="./output_createSMs.log"
echo "" > $LOG_FILE
###############################################
###############################################
###############################################

#
# Get the users list
#
function listUsers {
	NAMES=`curl -s -u ${CAPIADMIN}:${CAPIPASS} --connect-timeout ${TIMEOUT} -H "Accept:application/xml" --url http://${CAPI}/customers | grep login | sed -n -e 's/login//g' -e 's/[<>/ ]//gp'`
	for name in $NAMES
	do
		if [ $name = "admin" ]
		then
			continue
		fi
		# Create the SmartMachines
		createMachines
	done
}

#
# Create the machines
#
function createMachines {
	i=0;
	echo "[`date "+%y-%m-%d|%H:%M:%S"`] -----------Starting provisionning for user ${name}-------------" >> ${LOG_FILE}
	while [ $i -lt $NB_MACHINES ]
	do
		echo "[`date "+%y-%m-%d|%H:%M:%S"`] -----------------------------------------------------------"
		ERROR=`curl -isk -u ${CLOUDAPIUSER}:${CLOUDAPIPASS} --connect-timeout ${TIMEOUT} -H "X-Api-Version: ${CLOUDAPIVERSION}" --url https://${CLOUDAPI}/${name}/machines -d "name=${name}-machine${i}" -d package=${PACKAGE} -X POST | tee -a ${LOG_FILE} | grep message`
		if [ -n "$ERROR" ];
		then
			echo "[`date "+%y-%m-%d|%H:%M:%S"`] Create SmartOS SmartMachine number ${i} for user ${name} - NOT OK - ${ERROR}"
		else
			echo "[`date "+%y-%m-%d|%H:%M:%S"`] Create SmartOS SmartMachine number ${i} for user ${name} - OK"
		fi		
		i=`expr $i + 1`
	done
	echo "[`date "+%y-%m-%d|%H:%M:%S"`] -----------------------------------------------------------"
	echo -e "\n[`date "+%y-%m-%d|%H:%M:%S"`] -----------End provisionning for user ${name}-------------" >> ${LOG_FILE}
}

listUsers
exit 0