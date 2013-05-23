#!/bin/sh

###
# add users to the lpadmin group based on munki role defined in help desk
#
# if role is teacher, add assigned client/user to lpadmin
# if role is student, add an OD group that contains staff who should be
#   added. this allows any designated staff to be able to resume printing
#   on a student machine
###

### this script also uses the webhelpdesk lookup system
API_URL="http://helpdesk.example.com:8003/whd_helpers/getfield.php"

### Script action ###

dotversion=`facter | grep macosx_productversion_major | cut -d'.' -f2`
if [[ ${dotversion} -lt 7 ]]; then
	logger "${0}: this script requires mac os x 10.7 or higher."
	exit 0
fi

# see if the api script is installed and functioning

###
# replace functionality of the localusers puppet class (as far as managing _lpadmin group) since this script and that class's functionality are mutually exclusive
###
for user in sysop techhelper root; do
	dseditgroup -o edit -a ${user} -t user _lpadmin
done

defaultinterface=`/usr/sbin/netstat -rn | /usr/bin/grep default | /usr/bin/head -1 | /usr/bin/awk '{ print $6 }'`
if [ "${defaultinterface}" != "" ]; then
	ipaddrstart=`/sbin/ifconfig ${defaultinterface} | /usr/bin/grep broadcast | /usr/bin/awk '{ print $6 }' | /usr/bin/cut -d. -f1-2`
	ip_address=`/sbin/ifconfig ${defaultinterface} | /usr/bin/grep "inet " | /usr/bin/head -1 | /usr/bin/awk '{ print $2 }'`
	if [ "${ipaddrstart}" == "10.11" ]; then		# make sure it's on campus since helpdesk isn't available off campus
		paDir=`dirname ${0}`

		hwAddress=`/sbin/ifconfig en0 | awk '/ether/ { gsub(":", ""); print $2 }'`
		
		role="`curl -s -d \"mac_address=${hwAddress}\" -G "${API_URL}" -d \"field=9\" | cut -d '_' -f2`"
		client="`curl -s -d \"mac_address=${hwAddress}\" -G "${API_URL}" -d \"field=10\"`"

		logger "role=${role}, client=${client}"


		case ${role} in
			"student")		ACTION="-a nm-staff -t group"
						ACTION_TXT="group nm-staff" ;;
			"teacher")		if [ "x${client}" != "x" ]; then
							ACTION="-a ${client} -t user"
							ACTION_TXT="user ${client}"
						else
							logger "${0}: should have added a user, but none specified in help desk."
							exit -1
						fi
						;;
			"lab")			ACTION="-a nm-staff -t group"
						ACTION_TXT="group nm-staff" ;;
			"studentservices")	if [ "x${client}" != "x" ]; then
							ACTION="-a ${client} -t user"
							ACTION_TXT="user ${client}"
						else
							logger "${0}: should have added a user, but none specified in help desk."
							exit -1
						fi
						;;
			*) 			logger "${0}: unconfigured role (${role})... can not proceed"
						exit -1 ;;
		esac

		dseditgroup -o edit ${ACTION} _lpadmin && logger "${0}: added ${ACTION_TXT} to _lpadmin because role=${role}"
	fi
fi
### Always exit with 0 status
exit 0



