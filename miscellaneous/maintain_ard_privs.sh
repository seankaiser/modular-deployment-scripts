#!/bin/sh

###
# enforce remote management settings
###

KS="/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart"
authusers="administrator,techhelper"
noauthusers="students"

$KS -configure -allowAccessFor -specifiedUsers
$KS -configure -access -off -users "${noauthusers}"
$KS -configure -access -on -privs -all -users "${authusers}"

exit 0
