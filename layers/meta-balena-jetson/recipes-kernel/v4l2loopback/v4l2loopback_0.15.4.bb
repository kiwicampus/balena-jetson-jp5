SUMMARY = "v4l2loopback: virtual video devices (rover WebRTC / stereo virtual cameras)"
DESCRIPTION = "Built with the kernel instead of on-device (kiwicampus/kernel-module-build), \
so the module matches this exact kernel (CONFIG_MODVERSIONS) and can be signed with it \
once module signing / lockdown is enabled."
HOMEPAGE = "https://github.com/v4l2loopback/v4l2loopback"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://COPYING;md5=b234ee4d69f5fce4486a80fdaf4a4263"

# v0.15.4, same version as the on-device builds in rover/configs/kernels/
SRC_URI = "git://github.com/v4l2loopback/v4l2loopback.git;protocol=https;branch=main"
SRCREV = "0f9ee86760b7f2bea174b7e3e7a1d38845da0ab4"

S = "${WORKDIR}/git"

inherit module

# Only the module; upstream "all" also builds the userspace utils.
MAKE_TARGETS = "v4l2loopback.ko"
MODULES_INSTALL_TARGET = "install"
EXTRA_OEMAKE += "KERNEL_DIR=${STAGING_KERNEL_DIR}"
