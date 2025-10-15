SUMMARY = "Deploy compressed flash artifacts"

LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://${BALENA_COREBASE}/COPYING.Apache-2.0;md5=89aea4e17d99a7cacdbeed46a0096b10"

inherit deploy

PN = "tegra-flash-dry"

# For the AGX Xavier Devkit, the capsule has been generated in the reference
# Linux_for_Tegra environment, in which we replaced uefi_jetson.bin
# with the one from a balenaOS yocto build, as well as the partition file
# /bootloader/t186ref/cfg/flash_t194_sdmmc.xml with the one in the jetson-flash
# Jetson Xavier assets. Note that all <filename> FILENAME.. attributes for the
# esp and balenaOS have been removed prior to creating the UEFI capsule.
# The steps for generating any UEFI Capsule can be consulted in the L4T 35.4.1
# DeveloperGuide, in the UpdateAndRedundancy section > Generating a Multi-Spec Capsule Payload
UEFI_CAPSULE:jetson-xavier = "TEGRA_BL_T194.Cap.gz"
UEFI_CAPSULE:kiwi-xavier = "TEGRA_BL_T194.Cap.gz"

# The same applies to the Xavier NX SD and eMMC, and the same capsule
# can be used for all T194-based devkits. The only difference is that
# the files flash_l4t_t194_spi_sd_p3668.xml and flash_l4t_t194_spi_emmc_p3668.xml
# have had their contents replaced with the ones from the jetson-flash device
# assets directory.
UEFI_CAPSULE:jetson-xavier-nx-devkit-emmc = "TEGRA_BL_T194.Cap.gz"
UEFI_CAPSULE:jetson-xavier-nx-devkit = "TEGRA_BL_T194.Cap.gz"

BOOTBLOB:kiwi-xavier = "bins_agx_xavier.tar.gz"
BOOTBLOB:jetson-xavier = "bins_agx_xavier.tar.gz"
BOOTBLOB:jetson-xavier-nx-devkit-emmc = "boot0_xavier_nx_emmc.tar.gz"
BOOTBLOB:jetson-xavier-nx-devkit = "boot0_xavier_nx_sd.tar.gz"

PARTSPEC:kiwi-xavier = "partition_specification194.txt"
PARTSPEC:jetson-xavier = "partition_specification194.txt"
PARTSPEC:jetson-xavier-nx-devkit-emmc = "partition_specification194_nxde.txt"
PARTSPEC:jetson-xavier-nx-devkit = "partition_specification194_nxde.txt"

# The boot blobs have been extracted from the initramfs of devices flashed with
# jetson-flash, right after provisioning. This ensures that the UEFI store
# is not populated with boot options that contain the GUIDs of the eMMC
# of the device used for development.
BOOT0_PREFLASHED = "boot0.img"
BOOT0_PREFLASHED:kiwi-xavier = "boot0_mmcblk0boot0.img"
BOOT0_PREFLASHED:jetson-xavier = "boot0_mmcblk0boot0.img"
BOOT0_PREFLASHED:jetson-xavier-nx-devkit-emmc = "boot0_mtdblock0.img"
BOOT0_PREFLASHED:jetson-xavier-nx-devkit = "boot0_mtdblock0.img"

BINARY_INSTALL_PATH = "/opt/tegra-binaries/"

SRC_URI = " \
    file://${BOOTBLOB};unpack=0 \
    file://${PARTSPEC} \
    file://${UEFI_CAPSULE};unpack=0 \
"

do_install() {
    # Ensure install is not executed until
    # do_unpack copies the archive
    while [ ! -f ${WORKDIR}/${BOOTBLOB} ]
    do
        sleep 1
    done

    while [ ! -f ${WORKDIR}/${UEFI_CAPSULE} ]
    do
        sleep 1
    done

    install -d ${D}/${BINARY_INSTALL_PATH}
    install ${WORKDIR}/${PARTSPEC} ${D}/${BINARY_INSTALL_PATH}/
    install ${WORKDIR}/${UEFI_CAPSULE} ${D}/${BINARY_INSTALL_PATH}/
}

install_artifacts_xavier() {
    install -m 0644 ${WORKDIR}/${BOOTBLOB} ${D}/${BINARY_INSTALL_PATH}/
    tar xf ${D}/${BINARY_INSTALL_PATH}/${BOOTBLOB} -C ${WORKDIR}/ ${BOOT0_PREFLASHED}
    install ${WORKDIR}/${BOOT0_PREFLASHED} ${D}/${BINARY_INSTALL_PATH}/
}

do_install:append:jetson-xavier() {
    install_artifacts_xavier
}

do_install:append:kiwi-xavier() {
    install_artifacts_xavier
}

do_install:append:jetson-xavier-nx-devkit-emmc() {
    install_artifacts_xavier
}

do_install:append:jetson-xavier-nx-devkit() {
   install_artifacts_xavier
}

do_deploy() {
    rm -rf ${DEPLOY_DIR_IMAGE}/$(basename ${BINARY_INSTALL_PATH}) || true
    mkdir -p ${DEPLOY_DIR_IMAGE}/$(basename ${BINARY_INSTALL_PATH})
    cp -r ${D}/${BINARY_INSTALL_PATH}/* ${DEPLOY_DIR_IMAGE}/$(basename ${BINARY_INSTALL_PATH})
}

do_deploy:append:kiwi-xavier() {
    tar xf ${WORKDIR}/${BOOTBLOB} -C ${DEPLOY_DIR_IMAGE}/tegra-binaries/
}

do_deploy:append:jetson-xavier() {
    tar xf ${WORKDIR}/${BOOTBLOB} -C ${DEPLOY_DIR_IMAGE}/tegra-binaries/
}

do_deploy:append:jetson-xavier-nx-devkit-emmc() {
    tar xf ${WORKDIR}/${BOOTBLOB} -C ${DEPLOY_DIR_IMAGE}/tegra-binaries/
}

do_deploy:append:jetson-xavier-nx-devkit() {
    tar xf ${WORKDIR}/${BOOTBLOB} -C ${DEPLOY_DIR_IMAGE}/tegra-binaries/
}

FILES:${PN} += " \
    /opt/tegra-binaries/* \
"

INHIBIT_PACKAGE_STRIP = "1"
INHIBIT_PACKAGE_DEBUG_SPLIT = "1"

# need to be redeployed on each build
# as this path is not cached
do_install[nostamp] = "1"
do_deploy[nostamp] = "1"
do_unpack[nostamp] = "1"
deltask do_configure
deltask do_compile

addtask do_deploy before do_package after do_install
