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

# Take ftrace out properly. CONFIG_FUNCTION_TRACER=n above never applied on its own, because
# STACK_TRACER and FUNCTION_GRAPH_TRACER both `select FUNCTION_TRACER` and a select beats an
# explicit =n. Unset the selecters first and FUNCTION_TRACER really goes, taking
# DYNAMIC_FTRACE and FTRACE_MCOUNT_RECORD with it.
#
# Why this matters beyond the _mcount calls: CONFIG_FTRACE_MCOUNT_RECORD adds the
# ftrace_callsites fields to struct module, which changes the module_layout symbol CRC. With
# CONFIG_MODVERSIONS=y that invalidates every out-of-tree .ko built against a kernel with a
# different answer, which is why rover/configs/kernels/ ended up carrying two v4l2loopback
# builds and rover/balena_start.sh had to probe
# /sys/kernel/debug/tracing/enabled_functions to pick one. With ftrace gone there is one
# kernel and one module.
#
# This is NOT the same as CONFIG_DYNAMIC_FTRACE=n on its own, which does not link at all:
# FUNCTION_TRACER=y without DYNAMIC_FTRACE leaves absolute R_AARCH64_ABS32 relocations
# against __crc_* symbols, and vmlinux is a PIE because CONFIG_RELOCATABLE=y. See 10c309c.
BALENA_CONFIGS:append = " no_ftrace"
BALENA_CONFIGS[no_ftrace] = " \
    CONFIG_STACK_TRACER=n \
    CONFIG_FUNCTION_GRAPH_TRACER=n \
    CONFIG_FUNCTION_PROFILER=n \
    CONFIG_FUNCTION_TRACER=n \
"

# Note on the CONFIG_FUNCTION_TRACER=n above: it does NOT take effect. CONFIG_STACK_TRACER
# and CONFIG_FUNCTION_GRAPH_TRACER both `select FUNCTION_TRACER`, and a select overrides an
# explicit =n. The shipped kernel really runs FUNCTION_TRACER=y, FUNCTION_GRAPH_TRACER=y,
# STACK_TRACER=y and "# CONFIG_DYNAMIC_FTRACE is not set". To actually disable it you have to
# unset CONFIG_STACK_TRACER first. Left as-is for now because it is not where the cost was.
#
# CONFIG_DYNAMIC_FTRACE is deliberately NOT enabled.
#
# It was tried (commit 0e22581) on the theory that FUNCTION_TRACER=y without DYNAMIC_FTRACE
# leaves an unconditional _mcount call in every kernel function. Measured on 4U081 it bought
# exactly nothing: an invalid syscall cost 1752 ns with static ftrace and 1749 ns with
# dynamic, i.e. inside noise. The real costs turned out to be KPTI and EL2/VHE, both handled
# below.
#
# It is worse than neutral, because it changes struct module (adding the ftrace_callsites
# fields), which changes the module_layout symbol CRC. With CONFIG_MODVERSIONS=y that
# invalidates every out-of-tree .ko built against the previous kernel, and the prebuilt
# v4l2loopback modules in rover/configs/kernels/ failed to load on kiwibot4F042 with
# "v4l2loopback: disagrees about version of symbol module_layout".
#
# Do not re-enable it without rebuilding and committing every .ko in rover/configs/kernels/.
#
# DO NOT set CONFIG_DYNAMIC_FTRACE=n. It was tried in 1cdc11e and it does not link:
#
#   aarch64-poky-linux-ld.bfd: lib/dynamic_debug.o: relocation R_AARCH64_ABS32 against
#       `__crc_dynamic_debug_exec_queries' can not be used when making a shared object
#   lib/dynamic_debug.o:(.rodata+0x8): dangerous relocation: unsupported relocation
#   make: *** [Makefile:1208: vmlinux] Error 1
#
# The kernel is linked as a PIE because CONFIG_RELOCATABLE=y (we keep KASLR, see kpti=off
# below), so with CONFIG_MODVERSIONS=y every __crc_* reference has to be PC relative.
# FUNCTION_TRACER=y with DYNAMIC_FTRACE=n leaves objects whose __crc_* comes out as an
# absolute R_AARCH64_ABS32, and the link fails. Three commits' worth of images
# (2094447, d1c89f5, 5585748) all built with DYNAMIC_FTRACE=y; 1cdc11e is the only
# configuration that failed, twice, in 81 seconds.
#
# So DYNAMIC_FTRACE stays at its Kconfig "default y". The prebuilt out-of-tree modules for
# this generation are the *_dftrace.ko files in rover/configs/kernels/, and
# rover/balena_start.sh picks them by probing /sys/kernel/debug/tracing/enabled_functions.
#
# If you want ftrace gone for real, the lever is CONFIG_STACK_TRACER=n plus
# CONFIG_FUNCTION_GRAPH_TRACER=n, which drops FUNCTION_TRACER and takes DYNAMIC_FTRACE with
# it. That is untested here and changes struct module a third time, so every .ko in
# rover/configs/kernels/ has to be rebuilt again. Measured benefit of dynamic over static
# ftrace was nil anyway: an invalid syscall cost 1752 ns static and 1749 ns dynamic.

# Run the kernel at EL1 instead of EL2 by disabling VHE. CONFIRMED on hardware:
# this removes the L1D wipe, cuts a syscall from 3937 to 1315 cycles, and takes total
# system CPU on 4U081 from 423% to 374% of 800% with the full ROS stack running.
# Verified afterwards that the L1D_CACHE_REFILL per syscall is 0.1, identical to JP4,
# and that IPC is restored (0.20 vs JP4's 0.18). The ROS stack is unaffected: the same
# error signatures appear in the same proportions as before the change.
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

# Keep the kernel work dir after the build. rm_work deletes recipe-sysroot-native, which is the
# cross toolchain that out-of-tree modules have to be built with, so without this the only way
# to produce a v4l2loopback.ko that matches the kernel we just shipped is to restore the sysroot
# with a separate bitbake run. CONFIG_MODVERSIONS=y means a module built against any other
# kernel is rejected with "disagrees about version of symbol module_layout", so the module has to
# be built here, right after the kernel, from this exact sysroot.
do_rm_work[noexec] = "1"

do_deploy[nostamp] = "1"
do_deploy[postfuncs] += "generate_extlinux_conf"
do_install[depends] += "${@['', '${INITRAMFS_IMAGE}:do_image_complete'][(d.getVar('INITRAMFS_IMAGE', True) or '') != '' and (d.getVar('TEGRA_INITRAMFS_INITRD', True) or '') == "1"]}"

# These are needed by tegraflash during signing
OVERLAY_DTB_FILE:append:jetson-agx-orin-devkit = " tegra234-p3737-overlay-pcie.dtbo,tegra234-p3737-audio-codec-rt5658-40pin.dtbo,tegra234-p3737-a03-overlay.dtbo,tegra234-p3737-a04-overlay.dtbo,tegra234-p3737-camera-dual-imx274-overlay.dtbo,AcpiBoot.dtbo,L4TConfiguration.dtbo,L4TRootfsInfo.dtbo,L4TRootfsABInfo.dtbo,L4TRootfsBrokenInfo.dtbo"

