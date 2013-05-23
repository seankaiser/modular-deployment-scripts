#!/bin/sh

######################################
#
# a hacked together api to access whd data stored in a mysql database
#
# by sean kaiser, northmont city schools
#
# version 1.0 	- 2013-01-23
#		- converted/combined script from existing query scripts for whd data stored in default frontbase database
#		
######################################


###
# the custom numbers would need to be changed to match your setup. unless you've added fields in the same order as we have, your numbers will be different
###

###
# global definitions
###
u="whdquery"					# a readonly mysql account
p=""						# if you want a password on account, set it here
d="whd_production"				# the whd database
h="mysql.example.com"				# your mysql server
MYSQL="/usr/bin/mysql"				# mysql binary location
timeout=1					# allow query to take this long to run before exiting

###
# build some functions
###
query() {


	if [ "x${p}" != "x" ]; then
		( ulimit -t ${timeout}; $MYSQL --skip-column-names -s -r -u ${u} -p${p} -h ${h} -D ${d} -e "${1}" 2>&1 )
	else
		( ulimit -t ${timeout}; $MYSQL --skip-column-names -s -r -u ${u} -h ${h} -D ${d} -e "${1}" 2>&1 )
	fi
}

show_usage() {
	exit 0

	echo "USAGE: ${0} field-id [serial|mac-address|tag] [serial|mac-address|tag to use]"
	echo ""
	echo "To look up information by serial number for the local machine, only specify a field-id or field-id followed by serial."
	echo "To look up information by serial number for a different machine, specify field-id, whether looking up serial number or mac-address, and specify the serial number or mac-address."
	echo ""
	show_fieldids
}

show_fieldids() {
	exit 0

	echo "Valid field-ids are:"
	echo "1	- network image (deprecated)"	
	echo "2	- network name"
	echo "3	- asset tag number"
	echo "4	- boot drive partition size (deprecated)"
	echo "5	- wlan network name"
	echo "6	- asset's location based on inventory (deprecated)"
	echo "7	- puppet classes (from extra classes for puppet field in help desk)"
	echo "8	- additional buildings (deprecated)"
	echo "9	- munki class (from extra classes for puppet field in help desk... prefixed by munki_)"
	echo "10	- assigned client username"
}

###
# figure out how script has been called and set things up if it's been called correctly
###
if [ $# -lt 1 ]; then
	show_usage
	exit -1
else
	field="${1}"
fi

if [ "${field}" == "help" ]; then
	show_usage
	exit 0
fi

if [ "x${2}" != "x" ]; then
	lookup="${2}"
	if [ "x${3}" != "x" ]; then
		case ${lookup} in
			"serial")	query_value="${3}"
					query_name="serial_number" ;; 
			"mac-address")	query_value=`echo ${3} | tr ':' '\0'`
					query_name="mac_address"  ;;
			"tag")		query_value="${3}"
					query_name="asset_number" ;;
			*)		show_usage
					exit -1
					;;
		esac
	else
		case ${lookup} in
			"serial")	query_value=`facter sp_serial_number`
					query_name="serial_number" ;; 
			"mac-address")	query_value=`facter macaddress_en0 | tr ':' '\0'`
					query_name="mac_address"  ;;
			"tag")		query_value="${3}"
					query_name="asset_number" ;;
			*)		show_usage
					exit -1
					;;
		esac
	fi
else
	lookup="serial"
	query_name="serial_number"
	query_value=`facter sp_serial_number`
fi


query_high=`echo ${query_value} | tr '[a-z]' '[A-Z]'`
query_low=`echo ${query_value} | tr '[A-Z]' '[a-z]'`

where_prefix="( asset.${query_name} = '${query_high}' OR asset.${query_name} = '${query_low}')"

###
# ensure mysql is installed
###
if [ ! -x ${MYSQL} ]; then
	echo "ERROR: MYSQL binary not found in expected location (${MYSQL})"
	exit -1
fi

###
# do the query and postprocess the result(s)
###
case ${field} in
1)	# network_image (deprecated)
	result=`query "SELECT asset_custom_field.string_value FROM asset_custom_field, asset WHERE ${where_prefix} AND asset_custom_field.entity_id = asset.asset_id AND asset_custom_field.definition_id = 1 LIMIT 1;"`
	;;

2)	# network_name
	result=`query "SELECT asset.network_name FROM asset WHERE ${where_prefix};"`
	;;

3)	# tag_number
	result=`query "SELECT asset.asset_number FROM asset WHERE ${where_prefix};"`
	;;

4)	# boot_drive_partition_size (deprecated)
	result=`query "SELECT asset_custom_field.string_value FROM asset_custom_field, asset WHERE ${where_prefix} AND asset_custom_field.entity_id = asset.asset_id AND asset_custom_field.definition_id = 41 LIMIT 1;"`
	;;

5)	# wlan_name
	result=`query "SELECT asset_custom_field.string_value FROM asset_custom_field, asset WHERE ${where_prefix} AND asset_custom_field.entity_id = asset.asset_id AND asset_custom_field.definition_id = 42 LIMIT 1;"`
	;;

6)	# location (deprecated)
	result=`query "SELECT location.location_name FROM location, asset WHERE ${where_prefix}  AND asset.location_id = location.location_id;"`
	result=`echo "${result}" | tr '[A-Z]' '[a-z]' | tr ' ' '_' | sed 's/;_/;/g'`
	result=`echo "${result}" | sed 's/^/bldg_/g' | sed 's/;/;bldg_/g'`

	;;

7)	# puppet_classes
	result=`query "SELECT asset_custom_field.string_value FROM asset_custom_field, asset WHERE ${where_prefix} AND asset_custom_field.entity_id = asset.asset_id AND asset_custom_field.definition_id = 43 LIMIT 1;"`
	result=`echo "${result}" |  tr '[A-Z]' '[a-z]' | sed 's/^ //g' | tr ' ' '_' | sed 's/;_/ /g'`
	for value in $result; do
		if [[ `echo ${value} | grep -c "munki"` -eq 0 ]]; then
			if [ "x${modresult}" == "x" ]; then
				modresult="${value}"
			else
				modresult="${modresult};${value}"
			fi
		fi
	done
	result="${modresult}"
	;;

8)	# building(s) (deprecated)
	result=`query "SELECT asset_custom_field.string_value FROM asset_custom_field, asset WHERE ${where_prefix} AND asset_custom_field.entity_id = asset.asset_id AND asset_custom_field.definition_id = 32 LIMIT 1;"`
	result=`echo "${result}" | tr '[A-Z]' '[a-z]' | tr ' ' '_' | sed 's/;_/;/g'`
	result=`echo "${result}" | sed 's/^/bldg_/g' | sed 's/;/;bldg_/g'`
	;;

9)	# munki_classes
	result=`query "SELECT asset_custom_field.string_value FROM asset_custom_field, asset WHERE ${where_prefix} AND asset_custom_field.entity_id = asset.asset_id AND asset_custom_field.definition_id = 43 LIMIT 1;"`
	result=`echo "${result}" |  tr '[A-Z]' '[a-z]' | sed 's/^ //g' | tr ' ' '_' | sed 's/;_/ /g'`
	for value in $result; do
		if [[ `echo ${value} | grep -c "munki"` -gt 0 ]]; then
			if [ "x${modresult}" == "x" ]; then
				modresult="${value}"
			else
				modresult="${modresult};${value}"
			fi
		fi
	done
	result="${modresult}"
	;;

10)	# assigned_client_username
	result=`query "SELECT client.user_name from asset, asset_client, client WHERE ${where_prefix} AND asset_client.asset_id = asset.asset_id AND asset_client.client_id = client.client_id LIMIT 1;"`
	;;

*)	# invalid
	# echo "ERROR: you've requested an invalid field"
	# show_fieldids
	exit -1
	;;

esac

###
# show the result(s)
###
echo ${result}

exit 0

