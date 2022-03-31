# images to build before building swupdate image
IMAGE_DEPENDS = "rbxos-ramdisk rbxos-image upgrade-keys"

# images and files that will be included in the .swu image
SWUPDATE_IMAGES = "rbxos-image Image cn9130-cf-base rbxos-ramdisk flash-image"

# a deployable image can have multiple format, choose one
SWUPDATE_IMAGES_FSTYPES[rbxos-image] = ".squashfs.aes"
SWUPDATE_IMAGES_FSTYPES[Image] = ".bin .version"
SWUPDATE_IMAGES_FSTYPES[cn9130-cf-base] = ".dtb"
SWUPDATE_IMAGES_FSTYPES[rbxos-ramdisk] = ".cpio.gz.u-boot .version"
SWUPDATE_IMAGES_FSTYPES[flash-image] = ".bin"
SWUPDATE_IMAGES_NOAPPEND_MACHINE[flash-image] = "1"

SWUPDATE_SIGNING = "RSA"
SWUPDATE_PRIVATE_KEY = "${RECIPE_SYSROOT}${datadir}/upgrade-keys/priv.pem"
SWUPDATE_PASSWORD_FILE = "${RECIPE_SYSROOT}${datadir}/upgrade-keys/.swupdate_priv_pwd"

# Customize upgrade package name
IMAGE_NAME = "rbxos-cn9130-cf-base-${RBXOS_SW_VERSION}"

