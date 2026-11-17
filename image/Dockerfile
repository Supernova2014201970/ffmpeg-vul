# FFmpeg ARVO dataset — reproduction environment.
#
# Build (context = the ffmpeg-vul/ directory):
#   docker build -f image/Dockerfile -t ffmpeg-vul:17f63d98 .
#
# The base image supplies the 2017-era OSS-Fuzz toolchain (Ubuntu 16.04, clang
# 6.0.0 trunk 321529, g++ 5.4, yasm/nasm, libFuzzer sources) plus a full
# upstream FFmpeg history.  That history stays in the image: the delivered tree
# is a real checkout of
#
#   17f63d98e679e88a64f96e4aefba57b12ca29a0c   n3.4-dev-874-g17f63d9, 2017-05-09
#
# with .git present and a clean work tree — the same commit the shipped
# src/ffmpeg-readonly snapshot was taken from (both have upstream's tree hash
# 227b26da).  Nothing is patched into it: the 11 fix patches live in
# /payload/patches and are applied to a copy at verify time (verify-one.sh).
#
#   /src/ffmpeg   the baseline checkout, detached at 17f63d98, .git intact
#   /payload      cases.tsv, 11 PoCs, 11 patches, vulnerabilities.json
#   /opt/ffdt     ffdt, lib.sh, build.sh, verify.sh, verify-one.sh,
#                 verify-one-by-one.sh, hand_repro.c
#   /out          repro-<fp>-<san>-<decoder>: the 11 baseline reproducers
#   /work         empty — verify runs build there
FROM n132/arvo:42474806-vul@sha256:95cd4fadae89976811235d6b70b4d750c42a380845f7df27dc644333fef05052

SHELL ["/bin/bash", "-c"]

COPY payload/ /payload/
COPY scripts/ /opt/ffdt/
COPY reports/ /opt/ffdt/reports/

# The base image's WORKDIR is /src/ffmpeg; move out of it so no RUN can
# recreate a directory we work in.
WORKDIR /opt/ffdt

# Keep exactly one source tree.  libfdk-aac (the third-party decoder behind case
# 42474895, whose fix is in FFmpeg's wrapper libavcodec/libfdk-aacdec.c) is
# built from the image and installed to /usr/local first — uninstrumented, which
# is still enough for ASan: the buffer is allocated by the instrumented
# libavcodec and the write goes through the intercepted memset.  Then the
# base image's other sources and its fuzz targets go away, and the tree is
# pinned to the commit this dataset ships.  The patch loop asserts every
# payload patch applies to that exact tree.
RUN set -eux; \
    chmod +x /opt/ffdt/ffdt /opt/ffdt/*.sh; \
    mv /src/fdk-aac /usr/src/fdk-aac; \
    cd /usr/src/fdk-aac; \
    autoreconf -fiv > /tmp/fdk-autoreconf.log 2>&1; \
    ./configure --prefix=/usr/local --disable-shared --enable-static \
      > /tmp/fdk-configure.log 2>&1; \
    make -j"$(nproc)" > /tmp/fdk-make.log 2>&1; \
    make install > /tmp/fdk-install.log 2>&1; \
    test -f /usr/local/include/fdk-aac/aacdecoder_lib.h; \
    test -f /usr/local/lib/libfdk-aac.a; \
    rm -rf /usr/src/fdk-aac /tmp/fdk-*.log; \
    find /src -mindepth 1 -maxdepth 1 ! -name ffmpeg -exec rm -rf {} +; \
    rm -rf /out/* /work/*; \
    cd /src/ffmpeg; \
    git config gc.auto 0; \
    git checkout -q -f --detach 17f63d98e679e88a64f96e4aefba57b12ca29a0c; \
    git reset -q --hard; \
    git clean -xffdq; \
    test "$(git rev-parse HEAD)" = 17f63d98e679e88a64f96e4aefba57b12ca29a0c; \
    test "$(git rev-parse 'HEAD^{tree}')" = 227b26daf8e6b9d02b973aefca8f6f47cd177f9d; \
    test "$(git log -1 --format='%ci')" = "2017-05-09 18:38:30 +0200"; \
    test -z "$(git status --porcelain)"; \
    for p in /payload/patches/*.patch; do git apply --check "$p"; done

ENV SRC=/src/ffmpeg \
    PAYLOAD=/payload \
    OUT=/out \
    WORK=/work \
    FFDT_TREE=/src/ffmpeg \
    PATH=/opt/ffdt:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Build the two instrumented baselines (ASan, UBSan) and the 11 reproducers,
# then run every PoC: on this tree each one must still crash, so a silent change
# in the baseline, a PoC or a patch would fail the build instead of turning up
# later in a report.  Writes /reports/verify.json and leaves /out warm; /work is
# emptied again so `verify-one.sh` still does real builds.
RUN set -eux; \
    ffdt verify --report /reports; \
    rm -rf /work/*

# The delivered layout, asserted.
RUN set -eux; \
    source /opt/ffdt/lib.sh; \
    test "$(ls /src)" = ffmpeg; \
    test -d "$TREE/.git"; \
    test "$(baseline_commit)" = 17f63d98e679e88a64f96e4aefba57b12ca29a0c; \
    test -z "$(git -C "$TREE" status --porcelain)"; \
    test -f "$TREE/configure"; \
    test -f "$TREE/libavcodec/h264_cavlc.c"; \
    test "$(ls /payload/patches/*.patch | wc -l)" = 11; \
    test "$(ls -d /payload/pocs/*/poc | wc -l)" = 11; \
    test "$(awk -F'\t' '!/^#/ && NF >= 8' /payload/cases.tsv | wc -l)" = 11; \
    test "$(ls /out | wc -l)" = 9; \
    test -z "$(ls -A /work)"

CMD ["/bin/bash"]
