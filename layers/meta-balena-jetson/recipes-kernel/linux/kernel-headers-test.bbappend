# Skip the kernel-headers-test check.
#
# The upstream recipe builds a throwaway container from
# balenalib/intel-nuc-debian:bullseye-20230328 and runs apt-get inside it to get a
# cross toolchain, then compiles the exported kernel headers as a sanity check.
# Debian's bullseye-security Release file expired on 2026-09-07, so apt-get now
# refuses to proceed and the task fails with:
#
#   E: Release file for .../bullseye-security/InRelease is expired
#   returned a non-zero code: 100
#
# That breaks do_compile on every build, on every commit. The recipe defines no
# do_install and produces no package, so nothing in the image depends on it - it is
# purely a check. Stub the task out rather than let a dead upstream apt repository
# block the OS build. Revert this when meta-balena moves the test to a base image
# whose Release file is still valid.
do_compile() {
    bbnote "kernel-headers-test skipped: Debian bullseye-security Release file expired"
}
