FILESEXTRAPATHS:append := ":${THISDIR}/files"

DEPENDS:append = " tegra-flash-dry"

# 98-resin-bootfiles-jetson-xavier
HOSTAPP_HOOKS:append:jetson-xavier = " \
    99-resin-uboot \
    98-resin-bootfiles-jetson-xavier \
"

HOSTAPP_HOOKS:append:jetson-xavier-nx-devkit-emmc = " \
    99-resin-uboot \
    98-resin-bootfiles-jetson-xavier-nx-devkit-emmc \
"


HOSTAPP_HOOKS:append:jetson-xavier-nx-devkit = " \
    99-resin-uboot \
    98-resin-bootfiles-jetson-xavier-nx-devkit \
"
