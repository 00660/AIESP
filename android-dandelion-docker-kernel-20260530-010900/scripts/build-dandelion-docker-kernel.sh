#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-$ROOT_DIR/work}"
KERNEL_REPO="${KERNEL_REPO:-https://github.com/danya2271/kuroneko_r_mt6765.git}"
KERNEL_REF="${KERNEL_REF:-rebase}"
DEFCONFIG="${DEFCONFIG:-blossom_stock_defconfig}"
ARCH="${ARCH:-arm64}"
BASE_CONFIG="${BASE_CONFIG:-$ROOT_DIR/current.config}"
FRAGMENT="${FRAGMENT:-$ROOT_DIR/config/docker-required.fragment}"
SRC_DIR="${SRC_DIR:-$WORK_DIR/kernel}"
OUT_DIR="${OUT_DIR:-$SRC_DIR/out}"
NEUTRON_CLANG_TAG="${NEUTRON_CLANG_TAG:-11032023}"
NEUTRON_CLANG_SHA256="${NEUTRON_CLANG_SHA256:-ba8c71078f647a22f6adb8c289210889718fc4b4250e9502ad3932dc1f65c4ec}"
NEUTRON_CLANG_URL="${NEUTRON_CLANG_URL:-https://github.com/Neutron-Toolchains/clang-build-catalogue/releases/download/$NEUTRON_CLANG_TAG/neutron-clang-$NEUTRON_CLANG_TAG.tar.zst}"
JOBS="${JOBS:-$(nproc)}"
KERNEL_RELEASE="${KERNEL_RELEASE:-4.19.127-perf-g7288046673d5}"
LOCALVERSION="${LOCALVERSION:--perf}"
APPLY_LEGACY_NIIGO_PATCHES="${APPLY_LEGACY_NIIGO_PATCHES:-0}"

export DEBIAN_FRONTEND=noninteractive

log() {
  printf '\n==> %s\n' "$*"
}

log "Install build dependencies"
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  bc bison build-essential ca-certificates ccache curl flex git \
  libelf-dev libssl-dev \
  gcc-aarch64-linux-gnu gcc-arm-linux-gnueabi gcc-arm-linux-gnueabihf \
  python3 rsync wget xz-utils zstd

mkdir -p "$WORK_DIR"

if [[ ! -d "$SRC_DIR/.git" ]]; then
  log "Clone kernel source: $KERNEL_REPO ($KERNEL_REF)"
  git clone --depth 1 --branch "$KERNEL_REF" "$KERNEL_REPO" "$SRC_DIR"
else
  log "Reuse existing kernel source"
  git -C "$SRC_DIR" fetch --depth 1 origin "$KERNEL_REF"
  git -C "$SRC_DIR" checkout FETCH_HEAD
fi

mkdir -p "$OUT_DIR"

download_neutron_clang() {
  local tarball="$WORK_DIR/neutron-clang-$NEUTRON_CLANG_TAG.tar.zst"

  if [[ -x "$SRC_DIR/clang/bin/clang" ]]; then
    return
  fi

  log "Install Neutron clang: $NEUTRON_CLANG_TAG"
  rm -rf "$SRC_DIR/clang"
  mkdir -p "$SRC_DIR/clang"
  curl -L "$NEUTRON_CLANG_URL" -o "$tarball"
  printf '%s  %s\n' "$NEUTRON_CLANG_SHA256" "$tarball" | sha256sum -c -
  tar -I zstd -xf "$tarball" -C "$SRC_DIR/clang"
  rm -f "$tarball"
  [[ -x "$SRC_DIR/clang/bin/clang" ]]
}

link_cross_toolchain() {
  local target_dir="$1"
  local triple="$2"
  shift 2

  rm -rf "$target_dir"
  mkdir -p "$target_dir/bin"

  for tool in "$@"; do
    local src
    src="$(command -v "$triple$tool")"
    ln -s "$src" "$target_dir/bin/$triple$tool"
  done
}

install_kknx_native_toolchains() {
  log "Install KKNX native toolchains"

  download_neutron_clang

  link_cross_toolchain \
    "$SRC_DIR/gcc-linaro-13.0.0-2022.10-x86_64_aarch64-linux-gnu" \
    aarch64-linux-gnu- \
    gcc ld as ar nm objcopy objdump strip

  link_cross_toolchain \
    "$SRC_DIR/gcc-linaro-13.0.0-2022.10-x86_64_arm-linux-gnueabihf" \
    arm-linux-gnueabihf- \
    gcc ld as ar nm objcopy objdump strip elfedit

  chmod +x "$SRC_DIR/clang.sh"
}

run_kknx_make() {
  (cd "$SRC_DIR" && ./clang.sh "$@")
}

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

apply_kknx_build_fixes() {
  log "Apply KKNX build compatibility fixes"

  python3 - "$SRC_DIR" <<'PY'
from pathlib import Path
import sys

src = Path(sys.argv[1])

cpuset = src / "kernel/cgroup/cpuset.c"
text = cpuset.read_text()
old = """static ssize_t cpuset_write_resmask_assist(struct kernfs_open_file *of,
\t\t\t\t\t   struct cs_target tgt, size_t nbytes,
\t\t\t\t\t   loff_t off)
{
\tpr_info("cpuset_assist: setting %s to %s\\n", tgt.name, tgt.cpus);
\treturn cpuset_write_resmask(of, tgt.cpus, nbytes, off);
}

static ssize_t cpuset_write_resmask_wrapper"""
new = """#ifdef CONFIG_CPUSET_ASSIST
static ssize_t cpuset_write_resmask_assist(struct kernfs_open_file *of,
\t\t\t\t\t   struct cs_target tgt, size_t nbytes,
\t\t\t\t\t   loff_t off)
{
\tpr_info("cpuset_assist: setting %s to %s\\n", tgt.name, tgt.cpus);
\treturn cpuset_write_resmask(of, tgt.cpus, nbytes, off);
}
#endif

static ssize_t cpuset_write_resmask_wrapper"""
if old in text:
    cpuset.write_text(text.replace(old, new, 1))
elif new not in text:
    raise SystemExit("expected cpuset_write_resmask_assist pattern not found")

vmscan = src / "mm/vmscan.c"
text = vmscan.read_text()
if "static DECLARE_RWSEM(shrinker_rwsem);" not in text and "static DEFINE_RWSEM(shrinker_rwsem);" not in text:
    old = "static DEFINE_RWLOCK(shrinker_rwlock);\n"
    new = "static DEFINE_RWLOCK(shrinker_rwlock);\nstatic DECLARE_RWSEM(shrinker_rwsem);\n"
    if old not in text:
        raise SystemExit("expected shrinker_rwlock declaration not found")
    vmscan.write_text(text.replace(old, new, 1))

sched = src / "kernel/sched/sched.h"
text = sched.read_text()
old = "#define BW_UNIT\t\t\t(1 << BW_SHIFT)\n#define RATIO_SHIFT\t\t8\n"
new = "#define BW_UNIT\t\t\t(1 << BW_SHIFT)\n#define RATIO_SHIFT\t\t8\n#define MAX_BW_BITS\t\t(64 - BW_SHIFT)\n#define MAX_BW\t\t\t((1ULL << MAX_BW_BITS) - 1)\n"
if old in text and "#define MAX_BW" not in text:
    text = text.replace(old, new, 1)
elif "#define MAX_BW" not in text:
    raise SystemExit("expected BW_UNIT pattern not found")

old = "static inline void check_for_migration(struct rq *rq, struct task_struct *p) { }\n\nstatic inline int sched_boost(void)"
new = "#ifndef CONFIG_MTK_SCHED_BIG_TASK_MIGRATE\nstatic inline void check_for_migration(struct rq *rq, struct task_struct *p) { }\n#endif\n\nstatic inline int sched_boost(void)"
if old in text:
    text = text.replace(old, new, 1)
elif new not in text:
    raise SystemExit("expected check_for_migration fallback pattern not found")

old = "static inline bool hmp_capable(void) { return false; }\nstatic inline bool is_max_capacity_cpu(int cpu) { return true; }\nstatic inline bool is_min_capacity_cpu(int cpu) { return true; }\n\nstatic inline int\npreferred_cluster"
new = "static inline bool hmp_capable(void) { return false; }\n#ifndef CONFIG_MTK_SCHED_BIG_TASK_MIGRATE\nstatic inline bool is_max_capacity_cpu(int cpu) { return true; }\nstatic inline bool is_min_capacity_cpu(int cpu) { return true; }\n#endif\n\nstatic inline int\npreferred_cluster"
if old in text:
    text = text.replace(old, new, 1)
elif new not in text:
    raise SystemExit("expected capacity fallback pattern not found")

old = "static inline int is_reserved(int cpu)\n{\n\treturn 0;\n}\n\nstatic inline enum sched_boost_policy sched_boost_policy(void)"
new = "#ifndef CONFIG_MTK_SCHED_BIG_TASK_MIGRATE\nstatic inline int is_reserved(int cpu)\n{\n\treturn 0;\n}\n#endif\n\nstatic inline enum sched_boost_policy sched_boost_policy(void)"
if old in text:
    text = text.replace(old, new, 1)
elif new not in text:
    raise SystemExit("expected is_reserved fallback pattern not found")
sched.write_text(text)

core = src / "kernel/sched/core.c"
text = core.read_text()
old = "const u64 min_cfs_quota_period = 1 * NSEC_PER_MSEC; /* 1ms */\n\nstatic int __cfs_schedulable"
new = "const u64 min_cfs_quota_period = 1 * NSEC_PER_MSEC; /* 1ms */\n/* More than 203 days if BW_SHIFT equals 20. */\nstatic const u64 max_cfs_runtime = MAX_BW * NSEC_PER_USEC;\n\nstatic int __cfs_schedulable"
if old in text and "static const u64 max_cfs_runtime" not in text:
    text = text.replace(old, new, 1)
elif "static const u64 max_cfs_runtime" not in text:
    raise SystemExit("expected CFS quota period pattern not found")
core.write_text(text)

fair = src / "kernel/sched/fair.c"
text = fair.read_text()
old = "#ifdef CONFIG_MTK_SCHED_INTEROP\n\t\tload  += mt_rt_load(i);\n#endif\n\n\t\tsgs->group_load += cpu_runnable_load(rq);"
new = "#ifdef CONFIG_MTK_SCHED_INTEROP\n\t\tsgs->group_load += mt_rt_load(i);\n#endif\n\n\t\tsgs->group_load += cpu_runnable_load(rq);"
if old in text:
    text = text.replace(old, new, 1)
elif new not in text:
    raise SystemExit("expected update_sg_lb_stats MTK interop pattern not found")

old = "#ifdef CONFIG_MTK_SCHED_INTEROP\n\t\twl += mt_rt_load(i);\n#endif\n\n\t\t/*\n\t\t * When comparing with imbalance, use cpu_runnable_load()"
new = "#ifdef CONFIG_MTK_SCHED_INTEROP\n\t\tload += mt_rt_load(i);\n#endif\n\n\t\t/*\n\t\t * When comparing with imbalance, use cpu_runnable_load()"
if old in text:
    text = text.replace(old, new, 1)
elif new not in text:
    raise SystemExit("expected find_busiest_queue MTK interop pattern not found")
fair.write_text(text)

for rel in ("kernel/Makefile", "mm/Makefile"):
    makefile = src / rel
    text = makefile.read_text()
    lines = [
        line for line in text.splitlines()
        if not line.startswith("ccflags-y += -mllvm ")
    ]
    makefile.write_text("\n".join(lines) + "\n")

makefile = src / "Makefile"
text = makefile.read_text()
lines = []
hot_cold_seen = False
for line in text.splitlines():
    if line == "KBUILD_CFLAGS   += -mllvm -hot-cold-split=true":
        if hot_cold_seen:
            continue
        hot_cold_seen = True
    lines.append(line)
makefile.write_text("\n".join(lines) + "\n")
PY
}

apply_kknx_build_fixes
install_kknx_native_toolchains

if [[ "$APPLY_LEGACY_NIIGO_PATCHES" == "1" ]]; then
  apply_source_patches
else
  log "Skip legacy niigo source patches"
fi

log "Prepare base config"
if [[ -f "$BASE_CONFIG" ]]; then
  cp "$BASE_CONFIG" "$OUT_DIR/.config"
else
  run_kknx_make "$DEFCONFIG"
fi

log "Merge Docker config fragment"
"$SRC_DIR/scripts/kconfig/merge_config.sh" -m -O "$OUT_DIR" "$OUT_DIR/.config" "$FRAGMENT"

log "Run olddefconfig"
run_kknx_make olddefconfig

log "Pin release metadata and Docker options"
"$SRC_DIR/scripts/config" --file "$OUT_DIR/.config" \
  --set-str LOCALVERSION "$LOCALVERSION" \
  --disable LOCALVERSION_AUTO \
  --set-val FRAME_WARN 8192 \
  --disable SCHED_BORE \
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

run_kknx_make olddefconfig

log "Build kernel image"
run_kknx_make "-j$JOBS" KERNELRELEASE="$KERNEL_RELEASE" Image.gz

ARTIFACT_DIR="$ROOT_DIR/artifacts"
mkdir -p "$ARTIFACT_DIR"

cp -f "$OUT_DIR/.config" "$ARTIFACT_DIR/config-docker-final"
printf '%s\n' "$KERNEL_RELEASE" > "$ARTIFACT_DIR/kernel-release"
cp -f "$OUT_DIR/arch/$ARCH/boot/Image.gz" "$ARTIFACT_DIR/Image.gz"

log "Docker config summary"
grep -E 'CONFIG_(FRAME_WARN|SCHED_BORE|SYSVIPC|POSIX_MQUEUE|CGROUP_PIDS|CGROUP_DEVICE|CFS_BANDWIDTH|PID_NS|IPC_NS|USER_NS|VETH|MACVLAN|OVERLAY_FS|BRIDGE_NETFILTER|NETFILTER_XT_MATCH_ADDRTYPE|IP_NF_TARGET_MASQUERADE|FHANDLE)=' "$ARTIFACT_DIR/config-docker-final" || true

log "Artifacts"
find "$ARTIFACT_DIR" -maxdepth 1 -type f -printf '%f %s bytes\n' | sort
