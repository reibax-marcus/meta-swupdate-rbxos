DESCRIPTION = "Generate upgrade dependencies that don't need to be in the upgrade package"
SECTION = ""

LICENSE = "CLOSED"

inherit native

DEPENDS = "gettext-native"

RDEPENDS:${PN} = "bash"

# Add all local files to be used during the SWU build process
# Files in here are dependencies of the process but we don't want them in the final package
SRC_URI = " \
    file://bitbake_upgrade_qc.sh \
    "

# We want to make sure that package version is always up to date. Reparse variable every time.
do_compile[nostamp]="1"

do_compile() {
    :
}

do_install() {
    install -d 0755 "${D}${bindir}"
    install -m 0755 "${WORKDIR}/bitbake_upgrade_qc.sh" "${D}${bindir}"
}

FILES:${PN} += "\
    ${datadir}/upgrade-conf \
               "

