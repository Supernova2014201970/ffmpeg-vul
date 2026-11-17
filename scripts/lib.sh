#!/bin/bash
# Shared helpers for the FFmpeg ARVO dataset: one baseline tree, one patch per
# fix commit, one reproducer per (source fingerprint, sanitizer, decoder).
#
# /src/ffmpeg                 upstream 17f63d98e679e88a64f96e4aefba57b12ca29a0c
#                             (n3.4-dev-874-g17f63d9, 2017-05-09), the base
#                             image's own checkout, git repo, detached
# /payload                    cases.tsv, pocs/, patches/, vulnerabilities.json
# /out/repro-<fp>-<san>-<dec> instrumented reproducer, one per (fingerprint,
#                             sanitizer, decoder)
# /work/build-<fp>-<san>      private build tree; its static libraries are used
#                             in place, nothing is installed
#
# <fp> is the source fingerprint (commit + sha256 of `git diff`), so the baseline
# and every patched copy get their own build directory without collisions.
set -uo pipefail

FFDT_HOME=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TREE=${FFDT_TREE:-/src/ffmpeg}
PAYLOAD=${PAYLOAD:-/payload}
OUT=${OUT:-/out}
WORK=${WORK:-/work}

die() { echo "error: $*" >&2; exit 1; }
ulimit -c 0 2>/dev/null || true   # a sanitizer crash must not leave core files

# One build per sanitizer — never merged (ASan+UBSan cross-talk makes unrelated
# UB elsewhere in the tree show up in every run).  The 2017 toolchain in the
# base image has no instrumented libc, so MemorySanitizer is not offered here.
san_profile() { case "$1" in
  address|asan) echo address ;; undefined|ubsan) echo undefined ;;
  *) die "unknown sanitizer '$1' (address|undefined)" ;;
esac; }

# The environment the OSS-Fuzz runner uses for each profile.
san_env() { case "$1" in
  address|asan) echo "ASAN_OPTIONS=allocator_may_return_null=1:detect_leaks=0:detect_container_overflow=1:detect_odr_violation=0:detect_stack_use_after_return=1:fast_unwind_on_fatal=0:handle_abort=1:handle_segv=1:handle_sigill=1:print_scariness=1:quarantine_size_mb=10:strict_memcmp=1:symbolize=1:use_sigaltstack=1:dedup_token_length=3" ;;
  undefined|ubsan) echo "UBSAN_OPTIONS=print_stacktrace=1:print_summary=1:symbolize=1:dedup_token_length=3" ;;
  *) die "unknown sanitizer '$1'" ;;
esac; }

san_flags() { case "$1" in
  address|asan) echo "-fsanitize=address -fsanitize-address-use-after-scope" ;;
  # alignment is switched off on purpose: FFmpeg reads 64 bits at a time from
  # unaligned stream pointers (AV_RB64/av_alias64 in ff_h2645_extract_rbsp and
  # friends) by design on x86, and UBSan reports every one of those before the
  # decoder reaches the bug the case is about — it fired on all three h264/hevc
  # cases here ahead of the array index error.  The index/overflow checks that
  # these cases are about stay on.
  undefined|ubsan) echo "-fsanitize=undefined -fno-sanitize=alignment -fno-sanitize-recover=undefined" ;;
  *) die "unknown sanitizer '$1'" ;;
esac; }

# Flags both the instrumented and the plain build use.
plain_flags() {
  echo "-O1 -gline-tables-only -fno-omit-frame-pointer -DFUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION"
}

# Source fingerprint <commit8>-<sha256(git diff)[:8]> of a git work tree, or a
# content hash for a plain copy without history (src/ffmpeg-readonly as shipped,
# or any --tree DIR that is not a git checkout).
src_fp() {
  local dir=$1 commit
  if commit=$(git -C "$dir" rev-parse HEAD 2>/dev/null); then
    printf '%s-%s' "${commit:0:8}" "$(git -C "$dir" diff | sha256sum | cut -c1-8)"
  else
    ( cd "$dir" && find . -path ./.git -prune -o -type f -print0 |
        LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | cut -c1-16 ) |
      { read -r hash; printf 'tree-%s' "$hash"; }
  fi
}

baseline_commit() { git -C "$TREE" rev-parse HEAD || die "$TREE is not a git work tree"; }

# run_poc <san> <binary> <poc> -> "<verdict><TAB><summary>"
#
#   CRASH  the sanitizer reported — the bug is present
#   CLEAN  exit status 0 and no report — the bug is gone
#   ERROR  neither: no report but the process did not exit 0
#
# ASan ends its report with a `SUMMARY: AddressSanitizer: ...` line, UBSan with
# `SUMMARY: UndefinedBehaviorSanitizer: ...`; older ASan runtimes without
# symbolization only print the `ERROR: AddressSanitizer` header, so match both.
# Reports carry no error count: callers fold ERROR into pass=false.
run_poc() {
  local san=$1 bin=$2 poc=$3 out sum rc
  [ -x "$bin" ] || die "missing reproducer $bin (run: ffdt verify)"
  [ -f "$poc" ] || die "missing PoC $poc"
  local envs; envs=$(san_env "$san")
  out=$(env $envs "$bin" "$poc" 2>&1) 2>/dev/null
  rc=$?
  sum=$(printf '%s\n' "$out" |
    grep -m1 -E '^(SUMMARY: [A-Za-z]+Sanitizer|==[0-9]+==ERROR: [A-Za-z]+Sanitizer)' || true)
  if [ -n "$sum" ]; then printf 'CRASH\t%s\n' "$sum"; return 0; fi
  if [ "$rc" -eq 0 ]; then printf 'CLEAN\t-\n'; return 0; fi
  printf 'ERROR\texit=%s\n' "$rc"
}

# ensure_libs <srcdir> <sanitizer> -> prints the private build directory
#
# Copies the tree to /work/build-<fp>-<san>/src (never builds inside the source
# tree), configures it with that sanitizer's flags and runs make once.  The
# static libraries stay in the build tree; ensure_repro links against them.
ensure_libs() {
  local dir=${1:?} s fp bld flags
  s=$(san_profile "${2:?}")
  [ -d "$dir" ] || die "no such source tree: $dir"
  [ -f "$dir/configure" ] || die "$dir/configure missing (it is tracked; never regenerate)"
  fp=$(src_fp "$dir"); bld="$WORK/build-$fp-$s"
  if [ -f "$bld/src/ffbuild/config.mak" ] && [ -f "$bld/src/libavcodec/libavcodec.a" ]; then
    echo "cached  $bld" >&2; printf '%s\n' "$bld"; return 0
  fi

  flags="$(plain_flags) $(san_flags "$s")"
  rm -rf "$bld"; mkdir -p "$bld/src" "$OUT"
  ( cd "$dir" && tar -cf - --exclude=./.git . ) | ( cd "$bld/src" && tar -xf - ) ||
    die "cannot copy $dir"
  cd "$bld/src" || die "cannot enter $bld/src"

  echo "build   $dir [$s] -> $bld" >&2
  # libfdk-aac is a third-party decoder the OSS-Fuzz image builds next to the
  # tree; enable it when it is installed, so ff_libfdk_aac_decoder exists like
  # upstream (case 42474895 is a bug in the FFmpeg wrapper around it).
  local extra=""
  if [ -f /usr/local/include/fdk-aac/aacdecoder_lib.h ]; then
    extra="--enable-libfdk-aac"
  fi
  ./configure --cc=clang --cxx=clang++ --ld=clang++ \
    --extra-cflags="$flags" --extra-cxxflags="$flags" --extra-ldflags="$flags" \
    --disable-shared --enable-static --disable-doc --disable-programs \
    --disable-network --disable-avdevice --disable-postproc --disable-avfilter \
    --disable-stripping $extra > "$bld/configure.log" 2>&1 ||
    { grep -E '^(ERROR|.*not found)' "$bld/configure.log" | head -n 6 >&2
      tail -n 6 "$bld/configure.log" >&2; die "configure failed ($fp/$s)"; }
  echo "make    $fp/$s" >&2
  make -j"$(nproc)" > "$bld/make.log" 2>&1 ||
    { grep -m5 -E 'error:' "$bld/make.log" >&2; tail -n 20 "$bld/make.log" >&2
      die "make failed ($fp/$s)"; }
  printf '%s\n' "$bld"
}

# ensure_repro <srcdir> <sanitizer> <decoder> -> prints /out/repro-<fp>-<san>-<dec>
#
# Links the tree's own fuzz target (tools/target_dec_fuzzer.c, the file the
# OSS-Fuzz builder compiles) with hand_repro.c, a driver that feeds a file to
# LLVMFuzzerTestOneInput once — no libFuzzer runtime.  FFMPEG_DECODER pins the
# decoder the case was found in, exactly like the OSS-Fuzz target name does.
ensure_repro() {
  local dir=${1:?} s dec fp bld bin flags deps
  s=$(san_profile "${2:?}"); dec=${3:?}
  fp=$(src_fp "$dir")
  bld=$(ensure_libs "$dir" "$s") || exit 1
  bin="$OUT/repro-$fp-$s-$dec"
  if [ -x "$bin" ]; then echo "cached  $bin" >&2; printf '%s\n' "$bin"; return 0; fi
  flags="$(plain_flags) $(san_flags "$s")"
  deps=$(sed -n 's/^EXTRALIBS *= *//p' "$bld/src/ffbuild/config.mak" | tr '\n' ' ')

  echo "link    $bin" >&2
  ( cd "$bld/src" && clang $flags -I. -DFFMPEG_DECODER="$dec" \
      tools/target_dec_fuzzer.c "$FFDT_HOME/hand_repro.c" -o "$bin.new" \
      libavcodec/libavcodec.a libavformat/libavformat.a libavutil/libavutil.a \
      $deps -lm -lpthread ) || die "hand reproducer build failed ($fp/$s/$dec)"
  mv -f "$bin.new" "$bin"

  # The instrumentation must really be in the binary.  Grep a file, not nm's
  # output: `nm | grep -q` dies from SIGPIPE under pipefail.
  nm "$bin" > "$bld/nm-$dec.txt" 2>/dev/null || die "nm failed on $bin"
  case "$s" in
    address) grep -q '__asan_' "$bld/nm-$dec.txt" || die "$bin is not ASan-instrumented" ;;
    undefined) grep -q '__ubsan_' "$bld/nm-$dec.txt" || die "$bin is not UBSan-instrumented" ;;
  esac
  echo "built   $bin ($(stat -c %s "$bin") bytes, $s, decoder $dec)" >&2
  printf '%s\n' "$bin"
}
