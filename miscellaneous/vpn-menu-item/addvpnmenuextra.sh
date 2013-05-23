#!/bin/sh

me=`ls -al /dev/console | awk '{ print $3 }'`
uid=`ls -aln /dev/console | awk '{ print $3 }'`

if [[ `defaults read com.apple.systemuiserver menuExtras -array | grep -c -i vpn` -ne 0 ]]; then
	echo "present"
else
	defaults write com.apple.systemuiserver menuExtras -array-add "/System/Library/CoreServices/Menu Extras/VPN.menu"
	uipid=`ps -ef | grep /System/Library/CoreServices/SystemUIServer.app/Contents/MacOS/SystemUIServer | grep $uid | grep -v grep | awk '{ print $2 }'`
	kill -9 $uipid
fi
