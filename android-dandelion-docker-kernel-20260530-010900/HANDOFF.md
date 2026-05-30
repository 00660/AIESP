# 89 AlphaDroid Docker kernel handoff

更新时间：2026-05-30 11:48

## 当前结论

- 目标机器：`192.168.2.89`
- 设备：Redmi 9A / `dandelion` / `blossom` / MT6765
- ROM：`AlphaDroid-14.0-20240902-blossom-vanilla-v2.4`
- 目标版本只按这版 XDA/发布渠道的最新 AlphaDroid 做，不迁移到其他 AlphaDroid 版本，不替换成 Xiaomi 官方源码。
- 维护者线索：`AsTechpro20`
- 当前内核：`4.19.127-perf-g7288046673d5`
- 当前 boot 已经过 Magisk 修补，boot/prebuilt 哈希不能用于判断源码来源。
- 本轮没有刷机，没有写入 `/dev/block/by-name/boot`。

## 来源链

- AlphaDroid 主 manifest：`https://github.com/AlphaDroid-Project/manifest`，分支 `alpha-14`。
- AlphaDroid OTA 仓库：`https://github.com/AlphaDroid-devices/OTA`，分支 `alpha-14`，定义官方 OTA JSON 结构，包含 `dt`、`common-dt`、`kernel` 字段规范。
- 发布线索与机器版本对齐：`AlphaDroid 2.4 | Android 14 QPR3`、日期 `02/09/24`、设备 `blossom`、维护者 `@astechpro20`。
- AsTechpro20 prebuilt kernel 仓库：`https://github.com/AsTechpro20/device_xiaomi_blossom-kernel`，分支 `fourteen`，是 prebuilt/headers 仓库，不是完整源码。
- KKNX 源码线索：`https://github.com/danya2271/kuroneko_r_mt6765`，当前采用分支 `rebase`，本地 Git 对象 HEAD 为 `eb67d7438d831400837c5856aab8354217d2e2ea`。

不要再用 `TelegramAt25/niigo_kernel_xiaomi_blossom` 的构建产物给 89 机器打包 boot。旧候选只保留为禁用证据。

## 当前备份与隔离状态

- 89 当前 boot 备份：`/data/adb/docker-kernel-backups/boot-before-dandelion-docker-20260530-060945.img`
- 该备份记录 SHA：`e64726670f1139bc289bdab44d76d409562f5e87882cafa6a7ed235fc453e8a8`
- 危险旧候选已在手机侧隔离：`/data/local/tmp/dandelion-docker-disabled-20260530/boot-docker-run-26660680879.img.DO-NOT-FLASH`
- 本地旧候选仍在：`android-dandelion-docker-kernel-20260530-010900/artifacts/boot-docker-run-26660680879.img`，不要刷。

本轮本地备份：

- `scripts/build-dandelion-docker-kernel.sh.bak-20260530-082315-alpha-kknx`
- `scripts/build-dandelion-docker-kernel.sh.bak-20260530-082558-before-prune-hw-disables`
- `.github/workflows/build-dandelion-docker-kernel.yml.bak-20260530-082331-alpha-kknx`
- `scripts/build-dandelion-docker-kernel.sh.bak-20260530-090402-use-kknx-native-config`
- `HANDOFF.md.bak-20260530-090402-use-kknx-native-config`
- `scripts/build-dandelion-docker-kernel.sh.bak-20260530-093918-fixed-neutron-toolchain`
- `HANDOFF.md.bak-20260530-093918-fixed-neutron-toolchain`
- `scripts/build-dandelion-docker-kernel.sh.bak-20260530-094152-neutron-clang-dir`
- `HANDOFF.md.bak-20260530-094152-neutron-clang-dir`
- `scripts/build-dandelion-docker-kernel.sh.bak-20260530-095646-system-cross-links`
- `HANDOFF.md.bak-20260530-095646-system-cross-links`
- `scripts/build-dandelion-docker-kernel.sh.bak-20260530-095840-armhf-prefix`
- `HANDOFF.md.bak-20260530-095840-armhf-prefix`
- `.github/workflows/build-dandelion-docker-kernel.yml.bak-20260530-100559-ubuntu2404`
- `HANDOFF.md.bak-20260530-100559-ubuntu2404`
- `scripts/build-dandelion-docker-kernel.sh.bak-20260530-102113-kknx-compile-fixes`
- `HANDOFF.md.bak-20260530-102113-kknx-compile-fixes`
- `scripts/build-dandelion-docker-kernel.sh.bak-20260530-103533-cfs-runtime`
- `HANDOFF.md.bak-20260530-103533-cfs-runtime`
- `scripts/build-dandelion-docker-kernel.sh.bak-20260530-104938-fair-compile`
- `HANDOFF.md.bak-20260530-104939-fair-compile`
- `scripts/build-dandelion-docker-kernel.sh.bak-20260530-105905-sched-debug`
- `HANDOFF.md.bak-20260530-105905-sched-debug`
- `scripts/build-dandelion-docker-kernel.sh.bak-20260530-111109-binder-module`
- `HANDOFF.md.bak-20260530-111109-binder-module`
- `scripts/build-dandelion-docker-kernel.sh.bak-20260530-112611-binder-module`
- `HANDOFF.md.bak-20260530-112611-binder-module`
- `scripts/build-dandelion-docker-kernel.sh.bak-20260530-113650-binder-user-tracking`
- `HANDOFF.md.bak-20260530-113650-binder-user-tracking`
- `scripts/build-dandelion-docker-kernel.sh.bak-20260530-114715-efi-nf-procfs`
- `HANDOFF.md.bak-20260530-114715-efi-nf-procfs`

## 脚本状态

- `scripts/build-dandelion-docker-kernel.sh` 默认源已改为 `https://github.com/danya2271/kuroneko_r_mt6765.git`
- 默认分支已改为 `rebase`
- 默认 defconfig 已改为 `blossom_stock_defconfig`
- `BASE_CONFIG` 仍默认使用当前 89 运行内核导出的 `current.config`
- 2026-05-30 09:10 起，构建脚本改为优先调用 KKNX 仓库自带 `clang.sh`，不再手写维护一整套 `make CC/LD/CROSS_COMPILE` 参数。
- 2026-05-30 09:40 起，不再执行 KKNX `prepare_compiler.sh` 里的在线 `antman` 流程；脚本改为固定下载 Neutron clang tag `11032023`，并校验 SHA256 `ba8c71078f647a22f6adb8c289210889718fc4b4250e9502ad3932dc1f65c4ec`。
- 固定下载的 Neutron clang tarball 解压到 `$SRC_DIR/clang`，保持 KKNX `clang.sh` 期望的 `clang/bin/clang` 路径。
- 2026-05-30 09:58 起，不再从 `snapshots.linaro.org` 下载 Linaro GCC 包；脚本改为使用 apt 安装的 `gcc-aarch64-linux-gnu` 和 `gcc-arm-linux-gnueabihf`，在 KKNX `clang.sh` 期望的 Linaro 目录名下创建 symlink。
- 2026-05-30 10:06 起，GitHub Actions runner 从 `ubuntu-22.04` 改为 `ubuntu-24.04`，用于满足 Neutron clang `11032023` 对 `GLIBC_2.36` 的运行时要求。
- `OUT_DIR` 默认对齐为 KKNX `clang.sh` 的源码内 `out`，artifact 仍只收集 `Image.gz`、`config-docker-final`、`kernel-release`。
- 最新失败日志里的 `cpuset_write_resmask_assist` 已补 `CONFIG_CPUSET_ASSIST` 条件保护；`kernel/Makefile` 和 `mm/Makefile` 的子目录 `ccflags-y += -mllvm ...` 已在构建时移除，避免和全局 LLVM 参数重复或不兼容。
- 2026-05-30 10:26 起，按 run `26671667343` 日志补 KKNX 编译兼容项：`mm/vmscan.c` 增加 `shrinker_rwsem` 声明；`kernel/sched/sched.h` 在 `CONFIG_MTK_SCHED_BIG_TASK_MIGRATE=y` 时避免 WALT fallback 与 `eas_plus.h` extern 冲突；`CONFIG_FRAME_WARN` 调整为 `8192` 以绕过 `fs/d_path.c:getcwd` 的 clang 栈帧 Werror。
- 2026-05-30 10:36 起，按 run `26671990647` 日志和 Linux 5.10/5.15 上游 CFS bandwidth 写法补 `MAX_BW_BITS`、`MAX_BW` 与 `max_cfs_runtime`，用于支持 `CONFIG_CFS_BANDWIDTH=y`。
- 2026-05-30 10:50 起，按 run `26672186420` 日志修 `kernel/sched/fair.c` 中 `CONFIG_MTK_SCHED_INTEROP` 两处错误累加目标；同时显式关闭非 Docker 必需且当前运行配置没有的 `CONFIG_SCHED_BORE`，避免 KKNX 默认开启未完整实现的 BORE helper。
- 2026-05-30 10:59 起，按 run `26672473142` 日志修 `kernel/sched/debug.c`：去掉对 `fair.c` 私有 inline `cfs_rq_of()` 的调试输出依赖，并修正 `irst`/`first` 变量 typo。
- 2026-05-30 11:37 起，按 run `26672678565` 和 `26673336612` 日志修 KKNX 默认编译路径：`kernel/module.c` 改用 `module_sect_attr.battr.attr.name` 访问 section 名；`drivers/android/binder.c` 在 `CONFIG_ANDROID_BINDER_USER_TRACKING=y` 但 `CONFIG_ANDROID_BINDER_LOGS` 未启用时使用本地 `timespec/timeval` 记录 transaction 时间，不依赖 binder logs 的 `binder_transaction_log_entry`。
- 2026-05-30 11:48 起，按 run `26673529149` 日志继续补 KKNX/clang 编译兼容：EFI libstub secureboot 变量名从 `L"..."` 改为 `u"..."`；`include/net/netfilter/nf_log.h` 给 `nf_log_trace()` 原型补分号；`net/core/net-procfs.c` 的 `softnet_stat`/`ptype` 改用 `proc_create_net()` 加 `seq_operations`。
- 旧 `niigo` 兼容补丁默认不执行，只有显式设置 `APPLY_LEGACY_NIIGO_PATCHES=1` 才会执行。
- 已移除默认 `MTK_*`、`MTK_LCM`、camera、GPS、display 相关禁用项，只保留 Docker 需要的内核配置补项和当前已禁用的 `FHANDLE` 策略。

## Docker 关键缺项

当前 89 运行配置和 KKNX blossom defconfig 都缺这些 Docker 关键项：

- `CONFIG_SYSVIPC`
- `CONFIG_POSIX_MQUEUE`
- `CONFIG_IPC_NS`
- `CONFIG_CGROUP_PIDS`
- `CONFIG_CGROUP_DEVICE`
- `CONFIG_CFS_BANDWIDTH`
- `CONFIG_MACVLAN`
- `CONFIG_NETFILTER_XT_MATCH_ADDRTYPE`
- `CONFIG_NETFILTER_XT_MATCH_IPVS`

当前已确认 89 运行内核已有：

- `CONFIG_CGROUPS=y`
- `CONFIG_MEMCG=y`
- `CONFIG_PID_NS=y`
- `CONFIG_NET_NS=y`
- `CONFIG_BRIDGE=y`
- `CONFIG_BRIDGE_NETFILTER=y`
- `CONFIG_VETH=y`
- `CONFIG_TUN=y`
- `CONFIG_OVERLAY_FS=y`

## 下一步安全流程

1. 先用 GitHub Actions 或 Linux 环境只构建 `Image.gz` 和 `config-docker-final`。
2. 先检查 `config-docker-final`，确认只补 Docker 项，没有动显示、相机、触控、GPS 等硬件相关配置。
3. 未确认构建配置前，不 repack boot，不推手机，不刷 boot。
4. 如果后续需要 SSH 操作 89，优先使用 `tools/phone_ssh.py`。

## 构建记录

- 2026-05-30 run `26669315582` 使用 Ubuntu clang 14 失败，错误为旧 LLVM 参数 `-ignore-tti-inline-compatible`、`-inline-instr-cost=8` 不被 clang 14 支持。
- 2026-05-30 run `26669575953` 已切到 `clang-r383902`，但 KKNX `Makefile` 仍有该 clang 不支持的内联优化参数；脚本现在只移除日志明确报错的 KBUILD_CFLAGS 行，并去掉重复的 `-hot-cold-split=true`。
- 2026-05-30 run `26669733084` 失败点为 `kernel/cgroup/cpuset.c` 的 `struct cs_target` 条件编译错误，以及 `kernel/Makefile`、`mm/Makefile` 的 `--enable-merge-functions`/重复 `--unroll-threshold`。
- 2026-05-30 run `26670452786` 已切到 KKNX `clang.sh` 路线，但长时间停在 `Build kernel`，运行中日志接口未生成完整日志；怀疑卡在 `prepare_compiler.sh` 的在线 `antman` 工具链安装。
- 2026-05-30 run `26671030079` 失败点已确认：Neutron clang 固定下载和 SHA 校验通过，但 `snapshots.linaro.org` 下载 aarch64 Linaro 工具链超时，导致 `tar` 收到空输入。
- 2026-05-30 run `26671399589` 走到了 `olddefconfig`，失败点为 Neutron clang 需要 `GLIBC_2.36`，而 `ubuntu-22.04` runner 只有 glibc 2.35。
- 2026-05-30 run `26671667343` 已进入正式编译，失败点为 `mm/vmscan.c` 缺 `shrinker_rwsem`、`kernel/sched/sched.h` 与 `eas_plus.h` 的 WALT fallback 声明冲突，以及 `fs/d_path.c` 在 `CONFIG_FRAME_WARN=2800` 下被 `-Wframe-larger-than` 当作错误。
- 2026-05-30 run `26671990647` 前述错误已通过，新的失败点为 `CONFIG_CFS_BANDWIDTH=y` 后 `kernel/sched/core.c` 引用未定义的 `max_cfs_runtime`。
- 2026-05-30 run `26672186420` 前述错误已通过，新的失败点为 `kernel/sched/fair.c` 的 `update_burst_penalty`/`restart_burst` 未声明，以及 `CONFIG_MTK_SCHED_INTEROP` 下 `load`/`wl` 未定义。
- 2026-05-30 run `26672473142` 前述错误已通过，新的失败点为 `kernel/sched/debug.c` 的 `entity_eligible(cfs_rq_of(...))` 和 `irst`/`first` typo。
- 2026-05-30 run `26672678565` 前述错误已通过，新的失败点为 `drivers/android/binder.c` 的 `e` 未声明，以及 `kernel/module.c` 的 `struct module_sect_attr` 没有 `name` 成员。
- 2026-05-30 run `26673336612` 前述 module 错误已通过，新的失败点为 `CONFIG_ANDROID_BINDER_LOGS` 未启用时 `binder_transaction_log_add`、`binder_transaction_log` 和 `binder_transaction_log_entry` 都不可用。
- 2026-05-30 run `26673529149` 前述 binder 错误已通过，新的失败点为 `drivers/firmware/efi/libstub/secureboot.c` 宽字符串类型不兼容；并发还暴露 `include/net/netfilter/nf_log.h` 少分号、`net/core/net-procfs.c` 引用不存在的 `softnet_seq_fops`/`ptype_seq_fops`。
- 2026-05-30 11:48 本地已修 EFI/nf_log/net-procfs 三处编译兼容，等待重新触发 GitHub Actions 验证。
