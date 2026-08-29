#!/bin/bash -e
# vim: set ts=4 sw=4 sts=4 et :

if [ "$VERBOSE" -ge 2 -o "$DEBUG" == "1" ]; then
    set -x
fi


source "${TEMPLATE_CONTENT_DIR}/vars.sh"
source "${TEMPLATE_CONTENT_DIR}/distribution.sh"

##### "=========================================================================
debug " Provisioning machine for Kali installation
##### "=========================================================================

# Create system mount points
prepareChroot
chroot_cmd apt-mark hold qubes-core-agent-networking

chroot_cmd apt-mark hold qubes-core-agent
chroot_cmd apt-mark hold qubes-core-agent-networking
chroot_cmd apt-mark hold qubes-gui-agent
chroot_cmd apt-mark hold linux-image-amd64
chroot_cmd apt-mark hold grub-pc

cp ${TEMPLATE_CONTENT_DIR}/../keys/kali-archive-keyring.gpg  "${INSTALL_DIR}/usr/share/keyrings/kali-archive-keyring.gpg"

sudo cat <<EOF > "${INSTALL_DIR}/etc/apt/sources.list.d/kali.sources"  
# Kali repository  
Types: deb
URIs: http://http.kali.org/kali/
Suites: kali-rolling
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/kali-archive-keyring.gpg
EOF

## Ensure proxy handling is set
chroot_cmd sh -c 'sed -i s%https://%http://HTTPS///% /etc/apt/sources.list.d/* '


##### "=========================================================================
debug " Installing packages from Kali
##### "=========================================================================
aptDistUpgrade

cat <<EOF >> "${INSTALL_DIR}/etc/apt/preferences.d/1hold"  

Package: wireguard
Pin: release *
Pin-Priority: -999

Package: linux-image-amd64
Pin: release *
Pin-Priority: -999
EOF

chroot_cmd sh -c 'sed -i s%https://%http://HTTPS///% /etc/apt/sources.list.d/* '
aptUpdate

#APT_GET_OPTIONS+=" --allow-downgrades "
installPackages ${SCRIPTSDIR}/packages_kali.list


# ==============================================================================
# Kill all processes and umount all mounts within ${INSTALLDIR}, but not
# ${INSTALLDIR} itself (extra '/' prevents ${INSTALLDIR} from being umounted)
# ==============================================================================
umount_all "${INSTALL_DIR}/" || true
