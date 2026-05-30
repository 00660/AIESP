# 89 AlphaDroid Docker kernel handoff

更新时间：2026-05-30 09:10

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

## 脚本状态

- `scripts/build-dandelion-docker-kernel.sh` 默认源已改为 `https://github.com/danya2271/kuroneko_r_mt6765.git`
- 默认分支已改为 `rebase`
- 默认 defconfig 已改为 `blossom_stock_defconfig`
- `BASE_CONFIG` 仍默认使用当前 89 运行内核导出的 `current.config`
- 2026-05-30 09:10 起，构建脚本改为优先调用 KKNX 仓库自带 `clang.sh`，不再手写维护一整套 `make CC/LD/CROSS_COMPILE` 参数。
- `prepare_compiler.sh` 只准备 KKNX `clang.sh` 需要的 `clang/` 和 aarch64 Linaro 工具链；脚本额外补齐 `clang.sh` 引用但仓库脚本未下载的 ARM32 Linaro 工具链目录。
- `OUT_DIR` 默认对齐为 KKNX `clang.sh` 的源码内 `out`，artifact 仍只收集 `Image.gz`、`config-docker-final`、`kernel-release`。
- 最新失败日志里的 `cpuset_write_resmask_assist` 已补 `CONFIG_CPUSET_ASSIST` 条件保护；`kernel/Makefile` 和 `mm/Makefile` 的子目录 `ccflags-y += -mllvm ...` 已在构建时移除，避免和全局 LLVM 参数重复或不兼容。
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
- 2026-05-30 09:10 本地已验证 `build-dandelion-docker-kernel.sh` 通过 `bash -n` 和 `git diff --check`；尚未完成新的 GitHub Actions 构建结果验证。
