DESCRIPTION = "Generate rbxos upgrade SWU image"
SECTION = ""

LICENSE = "CLOSED"

inherit swupdate
inherit rbxos-sw-version

DEPENDS += " rbxos-upgrade-depends rbxos-upgrade-depends-native upgrade-keys "

# Machine specific parameters
require rbxos-upgrade-${MACHINE_ARCH}.inc

# Files that do not need to be installed to the target system but are used in the package
do_copy_depends() {
    cp "${RECIPE_SYSROOT}/usr/src/swupdate/${PN}/sw-description" "${WORKDIR}"
}
addtask do_copy_depends before do_swuimage after do_compile

# Files that will be installed to the target system but come from external packages
# need to be added to the SRC_URI variable
do_swuimage:prepend() {
    orgsrcuri = d.getVar('SRC_URI', True)
    recipesysroot = d.getVar('RECIPE_SYSROOT', True)
    datadir = d.getVar('datadir', True)
    d.setVar('SRC_URI', orgsrcuri + ' file://' + recipesysroot + '/usr/src/swupdate/rbxos-upgrade/update.sh')
}

do_swuimage_qc() {
    cd ${B}
    bitbake_upgrade_qc.sh
}
addtask do_swuimage_qc after do_swuimage before do_populate_lic
