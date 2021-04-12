#!/bin/bash -e
# vim: set ts=4 sw=4 sts=4 et :

if [ "$VERBOSE" -ge 2 -o "$DEBUG" == "1" ]; then
    set -x
fi

source "${SCRIPTSDIR}/vars.sh"
source "${SCRIPTSDIR}/distribution.sh"

##### "=========================================================================
debug " Provisioning machine for Parrot installation
##### "=========================================================================

# Create system mount points
prepareChroot

chroot_cmd apt-key add - < ${SCRIPTSDIR}/../keys/parrot.asc
chroot_cmd apt-mark hold qubes-core-agent
chroot_cmd apt-mark hold qubes-core-agent-networking
chroot_cmd apt-mark hold qubes-gui-agent
chroot_cmd apt-mark hold linux-image-amd64
chroot_cmd apt-mark hold grub-pc

sudo cat <<EOF > "${INSTALLDIR}/etc/apt/sources.list.d/parrot.list"  
# ParrotOS repository  
deb http://deb.parrotsec.org/parrot rolling main contrib non-free
#deb-src http://HTTPS///deb.parrotsec.org/parrot stable main contrib non-free
EOF

## Ensure proxy handling is set
#chroot_cmd sh -c 'sed -i s%https://%http://HTTPS///% /etc/apt/sources.list.d/* '


##### "=========================================================================
debug " Installing packages from ParrotOS
##### "=========================================================================
aptDistUpgrade

cat <<EOF >> "${INSTALLDIR}/etc/apt/preferences.d/1hold"  

Package: wireguard
Pin: release *
Pin-Priority: -999

Package: linux-image-5.4.0-4parrot1-amd64
Pin: release *
Pin-Priority: -999

Package: linux-image-amd64
Pin: release *
Pin-Priority: -999
EOF

## Parrot rewrites the sources lists
## Ensure proxy handling is still set
#chroot_cmd sh -c 'sed -i s%https://%http://HTTPS///% /etc/apt/sources.list.d/* '
aptUpdate

APT_GET_OPTIONS+=" --allow-downgrades"
installPackages ${SCRIPTSDIR}/packages_parrot.list

##### "=========================================================================
debug " ParrotOS
##### "=========================================================================

# ==============================================================================
# Kill all processes and umount all mounts within ${INSTALLDIR}, but not
# ${INSTALLDIR} itself (extra '/' prevents ${INSTALLDIR} from being umounted)
# ==============================================================================
umount_all "${INSTALLDIR}/" || true
