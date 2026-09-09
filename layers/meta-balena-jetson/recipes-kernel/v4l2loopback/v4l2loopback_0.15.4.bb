SUMMARY = "v4l2loopback kernel module, built against this image's kernel"
DESCRIPTION = "Creates the virtual V4L2 devices the Kiwibot stack streams into (WEBRTC_CAMERA \
and STEREO_COLOR_VIRTUAL_CAMERA). Building it here, in the same bitbake run as the kernel, is \
the whole point: CONFIG_MODVERSIONS=y makes the kernel reject any out-of-tree module whose \
module_layout CRC disagrees, and every kernel config change that touches struct module \
invalidates a prebuilt .ko. That is how rover/configs/kernels/ ended up carrying several \
v4l2loopback builds and rover/balena_start.sh ended up probing \
/sys/kernel/debug/tracing/enabled_functions to guess which one to insmod. A module built \
from the kernel recipe's own sysroot always matches."
HOMEPAGE = "https://github.com/umlaeute/v4l2loopback"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://COPYING;md5=b234ee4d69f5fce4486a80fdaf4a4263"

inherit module

SRC_URI = "git://github.com/umlaeute/v4l2loopback.git;protocol=https;branch=main;tag=v0.15.4"
# v0.15.4, the version the prebuilt modules in rover/configs/kernels/ were built from
SRCREV = "0f9ee86760b7f2bea174b7e3e7a1d38845da0ab4"

S = "${WORKDIR}/git"

EXTRA_OEMAKE = "KERNELRELEASE=${KERNEL_VERSION} KERNEL_DIR=${STAGING_KERNEL_DIR}"

# Do NOT autoload. balena_start.sh loads it with the video_nr values it computes from
# WEBRTC_CAMERA and STEREO_COLOR_VIRTUAL_CAMERA, and an autoloaded instance would already
# hold the device numbers.
MODULES_MODULE_SYMVERS_LOCATION = "."
RPROVIDES:${PN} += "kernel-module-v4l2loopback"
