FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# 0001-configure-Prune-PIE-flags.patch dropped: upstream configure now strips
# -pie flags natively (different sed idiom, same effect), patch no longer applies.
SRC_URI = "git://git.yoctoproject.org/pseudo;branch=pseudo-1.9 \
           file://glibc238.patch \
           file://fallback-passwd \
           file://fallback-group \
           "
# older-glibc-symbols.patch dropped: upstream pseudo-1.9 already carries both
# fixes natively (prebuilt lib search path in Makefile.in, __register_atfork
# in pseudo_wrappers.c), patch is fully redundant now and no longer applies.
SRC_URI:remove = "file://older-glibc-symbols.patch"

# Bump past the oe-core branch tip: it lacks openat2 interception, which newer
# host glibc/tar opportunistically use, breaking pseudo's fd->path tracking
# ("got *at() syscall for unknown directory"). pseudo-1.9 branch has the fix.
SRCREV = "823895ba708c63f6ae4dcbfc266210f26c02c698"
PV = "1.9.8+git${SRCPV}"
