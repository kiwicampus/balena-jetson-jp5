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

# Kernel-entry cost: the CONFIG_FUNCTION_TRACER=n above does NOT take effect, because
# CONFIG_STACK_TRACER and CONFIG_FUNCTION_GRAPH_TRACER both `select FUNCTION_TRACER` in
# Kconfig, and a select overrides an explicit =n. The shipped kernel really runs:
#     CONFIG_FUNCTION_TRACER=y
#     CONFIG_FUNCTION_GRAPH_TRACER=y
#     CONFIG_STACK_TRACER=y
#     # CONFIG_DYNAMIC_FTRACE is not set     <-- the expensive part
# Without DYNAMIC_FTRACE ftrace cannot nop-patch its call sites, so EVERY kernel function
# carries an unconditional _mcount call for tracing nobody uses (current_tracer: nop).
# Measured on 4U081: getppid costs 3.13 CPU us/call vs 0.363/0.368 on two JP4 robots
# (which have FUNCTION_TRACER unset entirely) - a ~8x kernel-entry tax. ROS 2 loopback DDS
# is one recvmsg per subscriber per message, so that tax lands almost linearly on messaging;
# 90% of the JP5-vs-JP4 CPU gap sits in cyclonedds' recvUC thread.
#
# Rather than fight the selects, turn on the cheap variant: DYNAMIC_FTRACE is not selected
# by anything, and with it the call sites are patched to NOPs at boot, so tracing stays
# available at ~zero steady-state cost. CONFIG_HAVE_DYNAMIC_FTRACE=y on this kernel, so
# this is purely a config oversight, not a platform limitation.
BALENA_CONFIGS:append = " ftrace_dynamic"
BALENA_CONFIGS[ftrace_dynamic] = " \
    CONFIG_DYNAMIC_FTRACE=y \
"

# EXPERIMENT: run the kernel at EL1 instead of EL2 by disabling VHE.
#
# On this Carmel silicon, an EL0->EL2 exception invalidates the whole L1 data cache.
# Measured with the PMU on 4U081 (JP5, kernel at EL2 via VHE) against kiwibot4E290
# (JP4, kernel at EL1, no VHE, no KVM), same MIDR 0x4e0f0040, same 2.2656 GHz.
# A 32 KB userspace working set (512 lines) walked in a loop, L1D_CACHE_REFILL per pass:
#
#                        no syscall   1 syscall per pass
#   JP4 (EL1)                   1.2                  1.3   <- cache untouched
#   JP5 (EL2/VHE)               0.9                587.7   <- every line lost
#
# Cycles per pass go 650->1526 on JP4 but 604->6113 on JP5. Per invalid syscall the
# PMU shows L1D_CACHE_REFILL 0.1 (JP4) vs 73.2 (JP5) and STALL_BACKEND 57 vs 1991
# cycles, while L1D_TLB_REFILL is the same on both (12.4 vs 13.4) - so it is the L1
# data cache specifically, not the TLB, not the instruction side, not more code.
#
# JP4 ships "# CONFIG_ARM64_VHE is not set", which is why it does not pay this. We do
# not run KVM guests on the robot, so EL2 buys us nothing. With VHE off the kernel
# boots at EL1 and KVM, if ever used, falls back to nVHE.
BALENA_CONFIGS:append = " novhe"
BALENA_CONFIGS[novhe] = " \
    CONFIG_ARM64_VHE=n \
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

# kpti=off: KPTI costs ~2150 cycles on EVERY syscall on this CPU. Measured on 4U081 with a
# getppid/invalid-syscall microbenchmark using thread CPU time, over three separate boots:
# an invalid syscall (pure exception entry+exit, no handler work) costs 2691 ns / 6097 cycles
# with KPTI on and 1752 ns / 3968 cycles with it off. Every ROS node is syscall heavy, so this
# is a flat tax on the whole stack.
#
# This costs us no Meltdown protection. dmesg says "kernel page table isolation forced ON by
# KASLR", and booting with nokaslr alone makes the kernel decline to enable KPTI at all - so
# the CPU is either in the kernel's kpti_safe_list or reports ID_AA64PFR0_EL1.CSV3=1, i.e. not
# susceptible. KPTI was only hardening KASLR against address-leak timing attacks. We keep KASLR
# (hence kpti=off rather than nokaslr) and give up only that hardening of it.
#
# Spectre is NOT worth disabling: booting with mitigations=off moved the same benchmark by 0.1%.
KERNEL_ARGS:append:kiwi-xavier = " console=ttyTCU0,115200 loglevel=7 kpti=off"

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

