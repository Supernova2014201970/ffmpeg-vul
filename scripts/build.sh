#!/bin/bash
# Plain (non-instrumented) build of the baseline tree — no sanitizer, no
# reproducer, just the project's own configure and make.  This is the build a
# static-analysis or repair tool can drive.
#
#   build.sh [DIR]                default: /src/ffmpeg
#
# In-tree, so <DIR>/ffmpeg and <DIR>/ffprobe appear.  Re-running is cheap:
# configure is skipped once ffbuild/config.mak exists, and make is incremental.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

dir=${1:-$TREE}
[ -d "$dir" ] || die "no such directory: $dir"
[ -f "$dir/configure" ] || die "$dir/configure missing (it is tracked; never regenerate)"
start=$(date +%s)
cd "$dir"
if [ ! -f ffbuild/config.mak ]; then
  echo "== configure $dir"
  ./configure --cc=clang --cxx=clang++ --ld=clang++ \
    --extra-cflags="$(plain_flags)" --extra-cxxflags="$(plain_flags)" \
    --disable-doc --disable-stripping > /tmp/plain-configure.log 2>&1 ||
    { tail -n 6 /tmp/plain-configure.log; die "configure failed in $dir"; }
fi
echo "== make $dir"
make -j"$(nproc)" > /tmp/plain-make.log 2>&1 ||
  { tail -n 20 /tmp/plain-make.log; die "make failed in $dir"; }
[ -x ffmpeg ] || die "no ffmpeg after make in $dir"
echo "built $dir/ffmpeg ($(( $(date +%s) - start ))s) — $(./ffmpeg -version | sed -n 1p)"
