#!/bin/bash -e
# vim: set ts=4 sw=4 sts=4 et :

if [ "$VERBOSE" -ge 2 -o "$DEBUG" == "1" ]; then
    set -x
fi

source "${SCRIPTSDIR}/vars.sh"
source "${SCRIPTSDIR}/distribution.sh"

##### "=========================================================================
debug " Installing packages from qubes-vm-recommended in bullseye
##### "=========================================================================

updateDebianSourceList
aptUpdate
installPackages ${SCRIPTSDIR}/packages_qubes_bullseye.list
