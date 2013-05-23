<?php

	$output=shell_exec('/usr/local/bin/whdapi.sh ' . $_GET['field'] . ' ' . 'mac-address' . ' ' . $_GET['mac_address']);
	echo $output;
#}

?>
