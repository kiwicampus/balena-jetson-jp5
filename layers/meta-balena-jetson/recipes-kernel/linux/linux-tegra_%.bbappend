inherit kernel-resin deploy

FILESEXTRAPATHS:append := ":${THISDIR}/${PN}"

SCMVERSION="n"

# Switch nvmap to built-in to fix the kernel headers
SRC_URI:append = " file://0001-fix-kernel-headers-test.patch \
		file://0001-defconfig-Fix-build-failure.patch \
"

# Find kiwi-xavier dtb files
FILESEXTRAPATHS:prepend:kiwi-xavier := "${THISDIR}/files:"
SRC_URI:append:kiwi-xavier = " \
    file://tegra194-agx-kiwi-AGX.dts \
    file://tegra194-a02-bpmp-p2888-a04-kiwi.dts \
"


BALENA_CONFIGS:remove = " mdraid"

BALENA_CONFIGS:append = " debug_kmemleak "

BALENA_CONFIGS[debug_kmemleak] = " \
    CONFIG_HAVE_DEBUG_KMEMLEAK=n \
    CONFIG_DEBUG_KMEMLEAK=n \
    CONFIG_HAVE_DEBUG_KMEMLEAK=n \
    CONFIG_DEBUG_KMEMLEAK_SCAN_ON=n \
    CONFIG_FUNCTION_TRACER=n \
    CONFIG_HAVE_FUNCTION_TRACER=n \
    CONFIG_PSTORE=n \
"

BALENA_CONFIGS:append = " compat"
BALENA_CONFIGS[compat] = " \
                CONFIG_COMPAT=y \
"

BALENA_CONFIGS:append = " cdc-wdm"
BALENA_CONFIGS[cdc-wdm] = " \
                CONFIG_USB_WDM=m \
"

BALENA_CONFIGS:append = " sierra-net"
BALENA_CONFIGS[sierra-net] = " \
                CONFIG_USB_SIERRA_NET=m \
		CONFIG_PROC_KCORE=y \
"

BALENA_CONFIGS_DEPS[sierra-net] = " \
                CONFIG_USB_USBNET=m \
"

BALENA_CONFIGS:append = " cdc-ncm"
BALENA_CONFIGS[cdc-ncm] = " \
                CONFIG_USB_NET_CDC_NCM=m \
"

BALENA_CONFIGS_DEPS[cdc-ncm] = " \
                CONFIG_USB_USBNET=m \
"

BALENA_CONFIGS:append = " mii"

BALENA_CONFIGS:append = " rtl8822ce "
BALENA_CONFIGS[rtl8822ce] = " \
		CONFIG_RTL8822CE=m \
		CONFIG_RTK_BTUSB=m \
"

BALENA_CONFIGS:append = " nfsfs xudc"
BALENA_CONFIGS[nfsfs] = " \
    CONFIG_NFS_FS=m \
    CONFIG_NFS_V2=m \
    CONFIG_NFS_V3=m \
    CONFIG_NFS_V4=m \
    CONFIG_NFSD_V3=y \
    CONFIG_NFSD_V4=y \
"

BALENA_CONFIGS[xudc] = " \
    CONFIG_USB_TEGRA_XUDC=m \
"

BALENA_CONFIGS:append:jetson-agx-orin-devkit = " rtc"
BALENA_CONFIGS[rtc] = " \
    CONFIG_RTC_HCTOSYS_DEVICE="rtc0" \
    CONFIG_RTC_SYSTOHC_DEVICE="rtc0" \
"

BALENA_CONFIGS:append:jetson-orin-nano-devkit-nvme = " binder"
BALENA_CONFIGS[binder] = " \
    CONFIG_ANDROID=y \
    CONFIG_ASHMEM=y \
    CONFIG_ANDROID_BINDER_IPC=y \
    CONFIG_ANDROID_BINDER_DEVICES=\"binder,hwbinder,vndbinder\" \
    CONFIG_ANDROID_BINDER_IPC_SELFTEST=y \
"

L4TVER=" l4tver=${L4T_VERSION}"

KERNEL_ARGS = " firmware_class.path=/etc/firmware fbcon=map:0 rootdelay=1 roottimeout=120"
KERNEL_ARGS:append:jetson-xavier = " video=efifb:off nospectre_bhb "
KERNEL_ARGS:append:jetson-xavier-nx-devkit-emmc = " video=efifb:off nospectre_bhb "
KERNEL_ARGS:append:jetson-xavier-nx-devkit = " video=efifb:off nospectre_bhb "
KERNEL_ARGS += "${@bb.utils.contains('DISTRO_FEATURES','osdev-image',' mminit_loglevel=4 console=tty0 console=ttyTCU0,115200 ',' console=null quiet splash vt.global_cursor_default=0 consoleblank=0',d)} l4tver=${L4T_VERSION} "

# JP5 bring-up: keep the kernel console on the debug UART even on production images, so panics and
# resets leave a trace on the harness console capture (balenaOS default is console=null quiet splash).
KERNEL_ARGS:remove:kiwi-xavier = "console=null quiet splash"
KERNEL_ARGS:append:kiwi-xavier = " console=ttyTCU0,115200 loglevel=7"

# Kernel fix (KASAN, 2026-09-03): tegra210_adsp must not rename its registered platform device; the
# freed name left platform_device.name dangling -> use-after-free in platform_match -> heap corruption
# panics ~80-100 s after boot. 0002 patches the file the kernel builds; 0001 the tegra-alt duplicate.
SRC_URI:append:kiwi-xavier = " file://0001-tegra210-adsp-do-not-rename-registered-device.patch file://0002-tegra210-adsp-sound-soc-tegra-do-not-rename-device.patch file://0003-bluedroid_pm-do-not-kfree-embedded-wakeup-source.patch"

generate_extlinux_conf() {
    mkdir -p ${DEPLOY_DIR_IMAGE}/extlinux || true
    kernelRootspec="${KERNEL_ARGS}" ; cat >${DEPLOY_DIR_IMAGE}/extlinux/extlinux.conf << EOF
DEFAULT primary
TIMEOUT 10
MENU TITLE Boot Options
LABEL primary
      MENU LABEL primary ${KERNEL_IMAGETYPE}
      FDT default
      LINUX /boot/${KERNEL_IMAGETYPE}
      APPEND \${cbootargs} ${kernelRootspec} sdhci_tegra.en_boot_part_access=1 rootwait
EOF

}

DTBNAME = "${@os.path.basename(d.getVar('KERNEL_DEVICETREE', True).split()[0])}"

generate_extlinux_conf:kiwi-xavier() {
    mkdir -p ${DEPLOY_DIR_IMAGE}/extlinux || true
    kernelRootspec="${KERNEL_ARGS}" ; cat >${DEPLOY_DIR_IMAGE}/extlinux/extlinux.conf << EOF
DEFAULT primary
TIMEOUT 10
MENU TITLE Boot Options
LABEL primary
      MENU LABEL primary ${KERNEL_IMAGETYPE}
      FDT /boot/${DTBNAME}
      LINUX /boot/${KERNEL_IMAGETYPE}
      APPEND \${cbootargs} ${kernelRootspec} sdhci_tegra.en_boot_part_access=1 rootwait
EOF

}

do_configure:append:kiwi-xavier(){
    cp ${WORKDIR}/tegra194-a02-bpmp-p2888-a04-kiwi.dts ${S}/arch/${ARCH}/boot/dts
    echo 'dtb-y += tegra194-a02-bpmp-p2888-a04-kiwi.dtb' >> ${S}/arch/${ARCH}/boot/dts/Makefile

    # tegra194-agx-kiwi-AGX.dts #includes the stock galen kernel-dts common/
    # dtsi files by relative path, so it has to live alongside them, not in
    # the flat top-level dts dir.
    cp ${WORKDIR}/tegra194-agx-kiwi-AGX.dts ${S}/nvidia/platform/t19x/galen/kernel-dts/
    # Must land BEFORE the Makefile's own `dtb-y := $(addprefix $(makefile-path)/,$(dtb-y))`
    # step, or our entry never gets the platform/t19x/galen/kernel-dts/ path prefix the
    # other entries there get, and kbuild looks for the file one directory level too shallow.
    sed -i '/^dtb-\$(BUILD_19x_ENABLE) += tegra194-p2888-0001-p2822-0000.dtb$/a dtb-$(BUILD_19x_ENABLE) += tegra194-agx-kiwi-AGX.dtb' ${S}/nvidia/platform/t19x/galen/kernel-dts/Makefile
}

do_deploy[nostamp] = "1"
do_deploy[postfuncs] += "generate_extlinux_conf"
do_install[depends] += "${@['', '${INITRAMFS_IMAGE}:do_image_complete'][(d.getVar('INITRAMFS_IMAGE', True) or '') != '' and (d.getVar('TEGRA_INITRAMFS_INITRD', True) or '') == "1"]}"

# These are needed by tegraflash during signing
OVERLAY_DTB_FILE:append:jetson-agx-orin-devkit = " tegra234-p3737-overlay-pcie.dtbo,tegra234-p3737-audio-codec-rt5658-40pin.dtbo,tegra234-p3737-a03-overlay.dtbo,tegra234-p3737-a04-overlay.dtbo,tegra234-p3737-camera-dual-imx274-overlay.dtbo,AcpiBoot.dtbo,L4TConfiguration.dtbo,L4TRootfsInfo.dtbo,L4TRootfsABInfo.dtbo,L4TRootfsBrokenInfo.dtbo"

