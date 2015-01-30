#!/bin/sh

echo "ds_partition.sh - v3.0 ("`date`")"

P2_SIZE=0


# set the defaults for the script
let defaultBootSize=200
let minimum_users_size=75

echo "INFO: will attempt to set up 2 partitions"
requestedPartitions=2
bootSize=$defaultBootSize


P1_NAME="/Volumes/Macintosh\ HD"
TARGET_DEVICE=`diskutil info /Volumes/Macintosh\ HD | grep "Device Node:" | sed s/Device\ Node://g | sed s/\ *//`

if [ "_${TARGET_DEVICE}" = "_" ]
then
  echo "RuntimeAbortWorkflow: cannot get boot device"
  echo "ds_partition.sh - end"
  exit 1
else
  TARGET_DISK=`diskutil info /Volumes/Macintosh\ HD | grep "Device Node:" | sed s/Device\ Node://g | sed s/\ *// | sed s/s[0-9]$//g`
fi

DISK_NB=0
DEVICE_FOUND=0

# Display the final target device
echo "INFO: Target device: ${TARGET_DEVICE}"
echo "INFO: Target disk:   ${TARGET_DISK}"

# check to see if final target device has been partitioned already
let existing_partitions=0
if [[ “${1}” != "force" ]]; then
	existing_partitions=`df -k | grep -c ${TARGET_DISK}`
else
	existing_partitions=1
fi

echo "INFO: Current partitions: ${existing_partitions}"

if [[ $existing_partitions -eq 1 ]]; then	# drive has not been partitioned before

  # Find out the disk size
  DISK_SIZE_INFO=`diskutil info "${TARGET_DEVICE}" | grep "Total Size:"`
  DISK_SIZE_IN_BYTES=`echo ${DISK_SIZE_INFO} | awk '{print $5}' | cut -d'(' -f2`
  echo "INFO: Disk size: "${DISK_SIZE_IN_BYTES}" bytes"
  
  if [[ $requestedPartitions -gt 1 ]]; then
    # Compute the partitions size
    PARTITIONS_COUNT=2
    
    factor=`expr 1024 \* 1024 \* 1024`
    
    P1_SIZE=`expr ${bootSize} \* 1024 \* 1024 \* 1024`
    P2_MIN_SIZE=`expr ${minimum_users_size} \* 1024 \* 1024 \* 1024`
    P2_SIZE=`expr ${DISK_SIZE_IN_BYTES} - ${P1_SIZE}`
    P2_NAME="userHD"
    P2_FORMAT="JournaledHFS+"

    echo "INFO: ${P1_NAME} volume size set to: ${P1_SIZE} bytes"
    echo "INFO: Minimum ${P2_NAME} volume size is: ${P2_MIN_SIZE} bytes"
    echo "INFO: ${P2_NAME} volume size set to: ${P2_SIZE} bytes"

    if [[ ${DISK_SIZE_IN_BYTES} -lt ${P1_SIZE} ]]; then
        echo "WARN: physical drive size is less than specified boot volume size, not partitioning."
        echo "ds_partition.sh - end"
        exit 0
    fi

    if [[ ${P2_SIZE} -lt ${P2_MIN_SIZE} ]]; then
        echo "WARN: drive not large enough to ensure sufficient space for ${P2_NAME}, not partitioning."
        echo "ds_partition.sh - end"
        exit 0
    fi
    
    echo "INFO: Total: "`expr ${P1_SIZE} + ${P2_SIZE}`" bytes"
    
    echo "Partitioning disk "${TARGET_DEVICE}
    echo "diskutil resizeVolume $TARGET_DEVICE ${P1_SIZE}B ${P2_FORMAT} ${P2_NAME} ${P2_SIZE}B"
    
    diskutil resizeVolume $TARGET_DEVICE ${P1_SIZE}B ${P2_FORMAT} "${P2_NAME}" ${P2_SIZE}B 2>&1
    status=$?
  fi		# requestedPartitions > 1
    
  if [[ "${status}" -ne 0 ]]; then
    echo "RuntimeAbortWorkflow: cannot partition the device ${TARGET_DEVICE}"
    echo "ds_partition.sh - end"
    exit 1
  fi
    
#fi		# existing partitions = 1

  if [[ ${P2_SIZE} -ne 0 ]]; then
    chown techdept:admin "/Volumes/${P2_NAME}" 2>&1
    chmod 755 "/Volumes/${P2_NAME}" 2>&1
  fi

else
  echo "INFO: The disk (${TARGET_DISK}) has already been partitioned, not repartitioning."
fi

userHD_UUID=`diskutil info /Volumes/userHD | grep "Volume UUID:" | sed s/Volume\ UUID://g | sed s/\ *//`
uuidCount=`grep ${userHD_UUID} "/Volumes/Macintosh HD/private/etc/fstab" | grep -v \# | wc -l`

if [[ ${uuidCount} -eq 0 ]]; then
  echo "UUID=${userHD_UUID}	/Users	hfs rw" >> "/Volumes/Macintosh HD/private/etc/fstab"
  echo "INFO: added mount info for userHD to /etc/fstab"
else
  echo "INFO: mount info already exists in /etc/fstab, ensuring it's set to mount..."
  if [[ `grep ${userHD_UUID} "/Volumes/Macintosh HD/private/etc/fstab" | grep -c Users` -eq 0 ]]; then
    sed 's/noauto/\/Users/' "/Volumes/Macintosh HD/private/etc/fstab" > "/Volumes/Macintosh HD/private/etc/fstab"
    echo "INFO: mount info should now be set to mount in /etc/fstab"
  else
    echo "INFO: mount info already set to mount in /etc/fstab"
  fi
fi

mkdir /Volumes/userHD/Shared
chmod 1777 /Volumes/userHD/Shared
chown root:wheel /Volumes/userHD/Shared
echo "INFO: Created/updated userHD/Shared"

echo "ds_partition.sh - end"

exit 0
