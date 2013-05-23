#!/bin/sh

### Script action ###

whdapiurl="http://helpdesk.example.com:8000/whd_helpers/getfield.php"

if [ "x`sw_vers | grep Server`" != "x" ]; then
  logger "${0}: this is a server. don't rename myself."
  exit 0
fi

defaultinterface=`/usr/sbin/netstat -rn | /usr/bin/grep default | /usr/bin/head -1 | /usr/bin/awk '{ print $6 }'`
if [ "${defaultinterface}" != "" ]; then
	ipaddrstart=`/sbin/ifconfig ${defaultinterface} | /usr/bin/grep broadcast | /usr/bin/awk '{ print $6 }' | /usr/bin/cut -d. -f1-2`
	ip_address=`/sbin/ifconfig ${defaultinterface} | /usr/bin/grep "inet " | /usr/bin/head -1 | /usr/bin/awk '{ print $2 }'`
	if [ "${ipaddrstart}" = "10.11" ]; then					# make sure on campus since help desk is not available off campus
		paDir=`dirname ${0}`

		# Determine the OS of the target system and set the path of the SC file accordingly
		swVers=`defaults read "$1"/System/Library/CoreServices/SystemVersion ProductVersion | awk -F. '{print $2}'`
		if [ $swVers -ge 3 ]; then
			SC="/Library/Preferences/SystemConfiguration/preferences.plist"
		else
			SC="/private/var/db/SystemConfiguration/preferences.xml"
		fi
		
		hwAddress=`/sbin/ifconfig en0 | awk '/ether/ { gsub(":", ""); print $2 }'`
		
		logger "mac address is ${hwAddress} in set-name.sh, and i am `whoami`"
		computerName=`curl -s -G -d "mac_address=${hwAddress}" -d "field=2" -G "${whdapiurl}"`
		tag_number=`curl -s -G -d "mac_address=${hwAddress}" -d "field=3" -G "${whdapiurl}"`
		serial_number=`facter | grep serial | awk '{ print $3 }'`

		if [ "`echo ${computerName} | grep usage`" != "" ]; then
			echo "bad computer name found, exiting."
			exit 0
		else
			if [ "${computerName}" = "" ]; then
				echo "no computer name found, exiting."
				exit 0
			else
				rendezvousName=`echo "${computerName}" | cut -d' ' -f1`
				classicAtalkName="${computerName} (Classic)"
		
				# Provide a default name if the hardware address is not listed in the name table
				if [ "$computerName" == "" ]; then
					computerName=$hwAddress
				fi
			
				if [ "$rendezvousName" == "" ]; then
					rendezvousName="HW-$hwAddress"
				fi
			
				# Set the names using the "SetHostNames" application provided with NetRestore
				/usr/sbin/scutil --set ComputerName "${computerName}"
				/usr/sbin/scutil --set LocalHostName ${rendezvousName}
			
				# set the loginwindowtext to contain computer name, asset tag number, and serial number; also enable adminhostinfo
				if [ $swVers -ge 7 ]; then
					logger "setting loginwindowtext as computer name: ${computerName}, tag number: ${tag_number}, serial number: ${serial_number}"
					defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText "Computer name: ${computerName}\n\nTag number: ${tag_number}, Serial number: ${serial_number}"
					defaults write /Library/Preferences/com.apple.loginwindow AdminHostInfo HostName
				fi
			fi
		fi
	fi
fi
### Always exit with 0 status
exit 0

