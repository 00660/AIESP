#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-$ROOT_DIR/work}"
KERNEL_REPO="${KERNEL_REPO:-https://github.com/TelegramAt25/niigo_kernel_xiaomi_blossom.git}"
KERNEL_REF="${KERNEL_REF:-yoka_rb2}"
DEFCONFIG="${DEFCONFIG:-stock_defconfig}"
ARCH="${ARCH:-arm64}"
BASE_CONFIG="${BASE_CONFIG:-$ROOT_DIR/current.config}"
FRAGMENT="${FRAGMENT:-$ROOT_DIR/config/docker-required.fragment}"
OUT_DIR="${OUT_DIR:-$WORK_DIR/out}"
SRC_DIR="${SRC_DIR:-$WORK_DIR/kernel}"
JOBS="${JOBS:-$(nproc)}"
KERNEL_RELEASE="${KERNEL_RELEASE:-4.19.127-perf-g7288046673d5}"
LOCALVERSION="${LOCALVERSION:--perf}"

export DEBIAN_FRONTEND=noninteractive

log() {
  printf '\n==> %s\n' "$*"
}

log "Install build dependencies"
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  bc bison build-essential ca-certificates ccache curl flex git \
  libelf-dev libssl-dev lld llvm clang \
  gcc-aarch64-linux-gnu gcc-arm-linux-gnueabi \
  python3 rsync xz-utils

mkdir -p "$WORK_DIR" "$OUT_DIR"

if [[ ! -d "$SRC_DIR/.git" ]]; then
  log "Clone kernel source: $KERNEL_REPO ($KERNEL_REF)"
  git clone --depth 1 --branch "$KERNEL_REF" "$KERNEL_REPO" "$SRC_DIR"
else
  log "Reuse existing kernel source"
  git -C "$SRC_DIR" fetch --depth 1 origin "$KERNEL_REF"
  git -C "$SRC_DIR" checkout FETCH_HEAD
fi

log "Prepare base config"
if [[ -f "$BASE_CONFIG" ]]; then
  cp "$BASE_CONFIG" "$OUT_DIR/.config"
else
  make -C "$SRC_DIR" O="$OUT_DIR" ARCH="$ARCH" "$DEFCONFIG"
fi

log "Merge Docker config fragment"
"$SRC_DIR/scripts/kconfig/merge_config.sh" -m -O "$OUT_DIR" "$OUT_DIR/.config" "$FRAGMENT"

MAKE_ARGS=(
  -C "$SRC_DIR"
  O="$OUT_DIR"
  ARCH="$ARCH"
  CC=clang
  HOSTCC=clang
  HOSTCXX=clang++
  LD=ld.lld
  CLANG_TRIPLE=aarch64-linux-gnu-
  CROSS_COMPILE=aarch64-linux-gnu-
  CROSS_COMPILE_ARM32=arm-linux-gnueabi-
)

log "Run olddefconfig"
make "${MAKE_ARGS[@]}" olddefconfig

log "Pin release metadata and Docker options"
"$SRC_DIR/scripts/config" --file "$OUT_DIR/.config" \
  --set-str LOCALVERSION "$LOCALVERSION" \
  --disable LOCALVERSION_AUTO \
  --enable IKCONFIG \
  --enable IKCONFIG_PROC \
  --enable SYSVIPC \
  --enable POSIX_MQUEUE \
  --enable IPC_NS \
  --enable PID_NS \
  --enable NET_NS \
  --disable USER_NS \
  --enable CGROUP_PIDS \
  --enable CGROUP_DEVICE \
  --enable CFS_BANDWIDTH \
  --enable BRIDGE \
  --enable BRIDGE_NETFILTER \
  --enable VETH \
  --enable MACVLAN \
  --enable NETFILTER_XT_MATCH_ADDRTYPE \
  --enable NETFILTER_XT_MATCH_CONNTRACK \
  --enable NETFILTER_XT_MATCH_IPVS \
  --enable IP_NF_TARGET_MASQUERADE \
  --enable IP_NF_TARGET_REDIRECT \
  --enable OVERLAY_FS \
  --disable FHANDLE

make "${MAKE_ARGS[@]}" olddefconfig

log "Build kernel image"
make -j"$JOBS" "${MAKE_ARGS[@]}" KERNELRELEASE="$KERNEL_RELEASE" Image.gz

ARTIFACT_DIR="$ROOT_DIR/artifacts"
mkdir -p "$ARTIFACT_DIR"

cp -f "$OUT_DIR/.config" "$ARTIFACT_DIR/config-docker-final"
printf '%s\n' "$KERNEL_RELEASE" > "$ARTIFACT_DIR/kernel-release"
cp -f "$OUT_DIR/arch/$ARCH/boot/Image.gz" "$ARTIFACT_DIR/Image.gz"

log "Docker config summary"
grep -E 'CONFIG_(SYSVIPC|POSIX_MQUEUE|CGROUP_PIDS|CGROUP_DEVICE|CFS_BANDWIDTH|PID_NS|IPC_NS|USER_NS|VETH|MACVLAN|OVERLAY_FS|BRIDGE_NETFILTER|NETFILTER_XT_MATCH_ADDRTYPE|IP_NF_TARGET_MASQUERADE|FHANDLE)=' "$ARTIFACT_DIR/config-docker-final" || true

log "Artifacts"
find "$ARTIFACT_DIR" -maxdepth 1 -type f -printf '%f %s bytes\n' | sort
