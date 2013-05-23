# Multi-site reposado .htaccess file #

This is an example .htaccess which redirects contents/downloads requests on the reposado master server to the appropriate slave server. It also contains the sucatalog redirects to allow an administrator to set one sucatalog url on a client, regardless of OS version, and have the server redirect that request to the appropriate OS version's catalog on the server. This is [documented in the reposado wiki](https://github.com/wdas/reposado/blob/master/docs/URL_rewrites.txt).
