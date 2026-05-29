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

apply_source_patches() {
  log "Apply source compatibility patches"

  python3 - "$SRC_DIR" <<'PY'
from pathlib import Path
import sys

src = Path(sys.argv[1])

msg = src / "ipc/msg.c"
text = msg.read_text()
old = "\tif (IS_ENABLED(CONFIG_PROC_STRIPPED))\n\t\treturn err;\n\n\tipc_init_proc_interface"
new = "\tif (IS_ENABLED(CONFIG_PROC_STRIPPED))\n\t\treturn;\n\n\tipc_init_proc_interface"
if old not in text:
    raise SystemExit("expected msg_init PROC_STRIPPED return pattern not found")
msg.write_text(text.replace(old, new, 1))

sem = src / "ipc/sem.c"
text = sem.read_text()
old = "\tif (IS_ENABLED(CONFIG_PROC_STRIPPED))\n\t\treturn 0;\n\tipc_init_proc_interface"
new = "\tif (IS_ENABLED(CONFIG_PROC_STRIPPED))\n\t\treturn;\n\tipc_init_proc_interface"
if old not in text:
    raise SystemExit("expected sem_init PROC_STRIPPED return pattern not found")
sem.write_text(text.replace(old, new, 1))

tuning = src / "kernel/sched/extension/tuning.c"
text = tuning.read_text()
text = text.replace("\t\ttrace_sched_set_cpuprefer(p);\n", "")
tuning.write_text(text)

fair = src / "kernel/sched/fair.c"
text = fair.read_text()
text = text.replace(
    "\t\ttrace_sched_big_task_rotation(wr->src_cpu, wr->dst_cpu,\n"
    "\t\t\t\t\twr->src_task->pid, wr->dst_task->pid,\n"
    "\t\t\t\t\tfalse, set_uclamp);\n",
    "",
)
text = text.replace("\t\t\ttrace_sched_big_task_migration(p->pid, cpu, new_cpu);\n", "")
fair.write_text(text)

module = src / "kernel/module.c"
text = module.read_text()
text = text.replace("mod->sect_attrs->attrs[i].name", "mod->sect_attrs->attrs[i].battr.attr.name")
module.write_text(text)

cpumask = src / "include/linux/cpumask.h"
text = cpumask.read_text()
old = "#if NR_CPUS <= BITS_PER_LONG\n\t*cpumask_bits(dstp) = BIT(NR_CPUS) - 1;\n#else\n"
new = "#if NR_CPUS < BITS_PER_LONG\n\t*cpumask_bits(dstp) = BIT(NR_CPUS) - 1;\n#else\n"
if old not in text:
    raise SystemExit("expected cpumask_setall BIT pattern not found")
cpumask.write_text(text.replace(old, new, 1))

mrdump = src / "drivers/misc/mediatek/aee/mrdump/mrdump_helper.c"
text = mrdump.read_text()
old = "void aee_zap_locks(void)\n{\n\taee_wdt_zap_locks();\n}\n"
new = "void aee_zap_locks(void)\n{\n}\n"
if old in text:
    text = text.replace(old, new, 1)
mrdump.write_text(text)

mrdump_makefile = src / "drivers/misc/mediatek/aee/mrdump/Makefile"
text = mrdump_makefile.read_text()
flag = "ccflags-y += -Wno-unused-variable\n"
if flag not in text:
    text = text.replace("ccflags-y += -DTEXT_OFFSET=$(TEXT_OFFSET)\n", "ccflags-y += -DTEXT_OFFSET=$(TEXT_OFFSET)\n" + flag, 1)
mrdump_makefile.write_text(text)

devapc = src / "drivers/soc/mediatek/devapc/mt6765/devapc.c"
text = devapc.read_text()
include = "#include <linux/sched/clock.h>\n"
if include not in text:
    text = text.replace("#include <linux/sched.h>\n", "#include <linux/sched.h>\n" + include, 1)
devapc.write_text(text)

for makefile in (src / "drivers/misc/mediatek").rglob("Makefile"):
    text = makefile.read_text()
    if "fmradio" not in text:
        continue
    lines = [line for line in text.splitlines() if "fmradio" not in line]
    makefile.write_text("\n".join(lines) + "\n")
PY
}

apply_source_patches

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
  --disable DRM_VIRTIO_GPU \
  --disable MTK_COMBO_GPS \
  --disable MTK_GPS_SUPPORT \
  --disable MTK_GPS_EMI \
  --disable MTK_FMRADIO \
  --disable MTK_IMGSENSOR \
  --disable MTK_LENS \
  --disable MTK_CAM_CAL \
  --disable MTK_FLASHLIGHT \
  --disable MTK_CAMERA_ISP \
  --disable MTK_CAMERA_ISP_DPE_SUPPORT \
  --disable MTK_CAMERA_ISP_FD_SUPPORT \
  --disable MTK_CAMERA_ISP_CAMERA_SUPPORT \
  --disable MTK_LCM \
  --disable MTK_ROUND_CORNER_SUPPORT \
  --disable MTK_MMPROFILE_SUPPORT \
  --disable MMPROFILE \
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
