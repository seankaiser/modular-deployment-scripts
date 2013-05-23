# Munki preflight and postflight scripts #

With the exception of the preflight script, these scripts have been copied from other sources. The preflight script has evolved as we've deployed our machines and needed additional options configured. It dynamically sets the PkgURL option to point to the appropriate local munki repository, and also sets SoftwareUpdate's CatalogURL to use our reposado server for updates.
