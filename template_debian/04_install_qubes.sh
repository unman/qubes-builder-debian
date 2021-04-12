#!/bin/bash -e
# vim: set ts=4 sw=4 sts=4 et :

if [ "$VERBOSE" -ge 2 -o "$DEBUG" == "1" ]; then
    set -x
fi

source "${SCRIPTSDIR}/vars.sh"
source "${SCRIPTSDIR}/distribution.sh"

##### '-------------------------------------------------------------------------
debug ' Installing Qubes packages'
##### '-------------------------------------------------------------------------

# If .prepared_debootstrap has not been completed, don't continue
exitOnNoFile "${INSTALLDIR}/${TMPDIR}/.prepared_groups" "prepared_groups installataion has not completed!... Exiting"

# Create system mount points
prepareChroot

# ==============================================================================
# Execute any template flavor or sub flavor 'pre' scripts
# ==============================================================================
buildStep "${0}" "pre"

if ! [ -f "${INSTALLDIR}/${TMPDIR}/.prepared_qubes" ]; then
    #### '----------------------------------------------------------------------
    info ' Trap ERR and EXIT signals and cleanup (umount)'
    #### '----------------------------------------------------------------------
    trap cleanup ERR
    trap cleanup EXIT

    #### '----------------------------------------------------------------------
    info ' Install Qubes Repo and update'
    #### '----------------------------------------------------------------------
    installQubesRepo
    aptUpdate
    if [ ${DIST} == "bullseye" ]; then
    cat > "${INSTALLDIR}/etc/apt/preferences.d/1hold" <<'EOF'
Package: qubes-vm-recommended
Pin: release *
Pin-Priority: -999
EOF

    #### '----------------------------------------------------------------------
    info ' Execute any distribution specific flavor or sub flavor'
    #### '----------------------------------------------------------------------
    buildStep "${0}" "${DIST}"

    #### '----------------------------------------------------------------------
    info ' Install Qubes packages listed in packages_qubes.list file(s)'
    #### '----------------------------------------------------------------------
    if [ ${DIST} == "bullseye" ]; then
      APT_GET_OPTIONS+=" -o APT::Install-Recommends=0  -o APT::Install-Suggests=0"
      sed -i /qubes-vm-recommended/d ${SCRIPTSDIR}/packages_qubes_standard.list
    fi

   installPackages packages_qubes.list
   if [ ${DIST} == "bullseye" ]; then
     APT_GET_OPTIONS=${APT_GET_OPTIONS/ -o APT::Install-Recommends=0/}
     APT_GET_OPTIONS=${APT_GET_OPTIONS/ -o APT::Install-Suggests=0/}
     echo qubes-vm-recommended >> ${SCRIPTSDIR}/packages_qubes_standard.list
   fi


    if ! containsFlavor "minimal" && [ "0$TEMPLATE_ROOT_WITH_PARTITIONS" -eq 1 ]; then
        #### '------------------------------------------------------------------
        info ' Install kernel and bootloader'
        #### '------------------------------------------------------------------
        aptInstall qubes-kernel-vm-support
        aptInstall "${KERNEL_PACKAGE_NAME}"
        aptInstall grub-pc
        # find the right loop device, _not_ its partition
        dev=$(df --output=source $INSTALLDIR | tail -n 1)
        dev=${dev%p?}
        chroot_cmd mount -t devtmpfs none /dev
        chroot_cmd grub-install --target=i386-pc --modules=part_gpt "$dev"
        echo "grub-pc grub-pc/install_devices multiselect /dev/xvda" |\
            chroot_cmd debconf-set-selections
        chroot_cmd update-grub2
    fi

    uninstallQubesRepo

    #### '----------------------------------------------------------------------
    info ' Re-update locales'
    ####   (Locales get reset during package installation sometimes)
    #### '----------------------------------------------------------------------
    updateLocale

    #### '----------------------------------------------------------------------
    info ' Default applications fixup'
    #### '----------------------------------------------------------------------
    setDefaultApplications

    #### '----------------------------------------------------------------------
    info ' Cleanup'
    #### '----------------------------------------------------------------------
    umount_all "${INSTALLDIR}/" || true
    touch "${INSTALLDIR}/${TMPDIR}/.prepared_qubes"
    trap - ERR EXIT
    trap
fi

# ==============================================================================
# Execute any template flavor or sub flavor 'post' scripts
# ==============================================================================
buildStep "${0}" "post"

# ==============================================================================
# Kill all processes and umount all mounts within ${INSTALLDIR}, but not
# ${INSTALLDIR} itself (extra '/' prevents ${INSTALLDIR} from being umounted)
# ==============================================================================
umount_all "${INSTALLDIR}/" || true
