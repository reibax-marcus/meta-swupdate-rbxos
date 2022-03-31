FILESEXTRAPATHS:append := "${THISDIR}/${PN}:"

PACKAGECONFIG_CONFARGS = ""

SRC_URI += " \
     file://swupdate.cfg \
     file://launch-swupdate.sh \
     file://init-versions \
     file://swu-postinst \
     file://swu-run-postinsts \
     file://swu-run-postinsts.service \
     file://0001-Add-beautified-versions-of-index.html-and-swupdate.a.patch \
     file://0002-feature-add-reset-factory-actions.patch \
     file://0003-feature-Support-system-information-display.patch \
     "

RDEPENDS:${PN} += "bash upgrade-keys-sym upgrade-keys-pub"

SYSTEMD_SERVICE:${PN} = "swupdate.service swu-run-postinsts.service"

wwwdir = "/www/swupdate"

do_install:append() {
    install -d ${D}${sysconfdir}
    install -m 644 ${WORKDIR}/swupdate.cfg ${D}${sysconfdir}
    install -d ${D}/${bindir}
    install -m 755 ${WORKDIR}/launch-swupdate.sh ${D}/${bindir}
    install -m 755 ${WORKDIR}/init-versions ${D}/${bindir}
    install -d ${D}${sysconfdir}/swu-postinst/collection
    install -m 755 ${WORKDIR}/swu-postinst ${D}/${sysconfdir}/swu-postinst/collection/
    install -m 755 ${WORKDIR}/swu-run-postinsts ${D}/${bindir}
    install -m 644 ${WORKDIR}/swu-run-postinsts.service ${D}${systemd_system_unitdir}/
    install -d ${D}/${wwwdir}/keys
    install -d ${D}/${wwwdir}/images
    install -d "${D}/var/lib/swupdate"
    install -m 644 ${S}/examples/www/v2/index.rbxos.html  ${D}/var/lib/swupdate/index.html.template
    install -m 644 ${S}/examples/www/v2/index.rbxos.html ${D}/${wwwdir}/index.html
    install -m 644 ${S}/examples/www/v2/js/swupdate.rbxos.js ${D}/${wwwdir}/js/swupdate.min.js

    # Remove unnecessary services and udev rules
    rm ${D}${sysconfdir}/udev/rules.d/swupdate-usb.rules
}
