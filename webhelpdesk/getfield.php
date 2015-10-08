<?php

	$output=shell_exec('/usr/local/bin/whdapi.sh ' . escapeshellarg($_GET['field']) . ' ' . 'mac-address' . ' ' . escapeshellarg($_GET['mac_address']));
	echo $output;
#}

?>
