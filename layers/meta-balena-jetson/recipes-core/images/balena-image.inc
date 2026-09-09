IMAGE_FSTYPES += "balenaos-img"

do_rootfs:balenaos-img[depends] += " linux-tegra:do_deploy edk2-firmware-tegra:do_deploy l4t-launcher-extlinux:do_deploy tegra-flash-dry:do_install"
DTBFILE ?= "${@os.path.basename(d.getVar('KERNEL_DEVICETREE', True).split()[0])}"

IMAGE_INSTALL:append = " \
    tegra-flash-dry \
    kernel-image-initramfs \
    tegra-redundant-boot \
    tegra-nv-boot-control-config \
    tegra-eeprom-tool \
    setup-nv-boot-control \
"

# We don't mount or use the esp partition, so let's
# remove the systemd mounts that delay booting
IMAGE_INSTALL:remove = "setup-nv-boot-control-service"

MACHINE_EXTRA_RRECOMMENDS += " kernel-image-initramfs"
MACHINE_EXTRA_RDEPENDS += " kernel-image-initramfs"

XAVIER_PACKAGES = " \
    tegra-redundant-boot \
    tegra-nv-boot-control-config \
    parted \
    gptfdisk \
    tegra-bluetooth \
    tegra-wifi \
    tegra-nvpmodel \
    jetson-dtbs \
    tegra-configs-nvstartup \
    tegra-nvstartup \
    tegra-configs-udev \
    tegra-nvfancontrol \
    l4t-launcher-extlinux \
    pciutils \
    tegra-firmware \
    tegra-eeprom-tool \
    setup-nv-boot-control \
    ldd \
    tegra-firmware-rtl8822 \
    mtd-utils \
"

IMAGE_INSTALL:append:jetson-xavier = "${XAVIER_PACKAGES}"
IMAGE_INSTALL:append:kiwi-xavier = "${XAVIER_PACKAGES}"
IMAGE_INSTALL:append:jetson-xavier-nx-devkit-emmc = "${XAVIER_PACKAGES}"
IMAGE_INSTALL:append:jetson-xavier-nx-devkit = "${XAVIER_PACKAGES}"

IMAGE_INSTALL:remove = "kernel-image-image"

# Kiwibot: ship v4l2loopback built by this same bitbake run, so it always matches the kernel.
# CONFIG_MODVERSIONS=y makes the kernel reject any module whose module_layout CRC disagrees,
# and every config change that touches struct module invalidates a prebuilt .ko. The stack used
# to carry several v4l2loopback builds in rover/configs/kernels/ and probe
# /sys/kernel/debug/tracing/enabled_functions at boot to guess which one to insmod. A module
# built from the kernel recipe's own sysroot cannot mismatch, so that guessing goes away.
IMAGE_INSTALL:append:kiwi-xavier = " kernel-module-v4l2loopback"
