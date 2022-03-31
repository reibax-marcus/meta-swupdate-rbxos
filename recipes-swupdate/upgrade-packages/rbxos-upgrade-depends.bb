DESCRIPTION = "Generate upgrade dependencies that are either shared with other upgrade files or don't need to be in the upgrade package"
SECTION = ""

LICENSE = "CLOSED"

PACKAGE_ARCH = "${MACHINE_ARCH}"

DEPENDS = "gettext-native"

RDEPENDS:${PN} = "bash"

inherit rbxos-sw-version

# Add all local files to be added to the SWU
# sw-description must always be in the list.
# You can extend with scripts or wahtever you need
SRC_URI = " \
    file://sw-description.in \
    file://update.sh \
    "

# We want to make sure that package version is always up to date. Reparse variable every time.
do_compile[nostamp]="1"

do_compile() {
    if [ -z ${RBXOS_SW_VERSION} ] ; then
        echo "ERROR: RBXOS_SW_VERSION variable is empty" >&2
        exit 2
    fi
    export RBXOS_SW_VERSION="${RBXOS_SW_VERSION}"
    mkdir -p "${B}"
    if [ $(echo '$RBXOS_SW_VERSION' | envsubst | wc -w) -lt 1 ] ; then
        echo "ERROR: envsubst is not working for RBXOS_SW_VERSION" >&2
        exit 2
    fi
    envsubst < "${WORKDIR}/sw-description.in" > "${B}/sw-description"
}

do_install() {
    CUSTOM_INSTALL_DIR="/usr/src/swupdate/$(echo ${PN} | sed 's/-depends//g')"
    install -d 0755 "${D}${CUSTOM_INSTALL_DIR}"
    install -m 0644 "${B}/sw-description" "${D}${CUSTOM_INSTALL_DIR}/"
    install -m 0644 "${WORKDIR}/update.sh" "${D}${CUSTOM_INSTALL_DIR}/"
}

FILES:${PN} += "\
    /usr/src/swupdate \
               "

SYSROOT_DIRS = "/usr/src"
