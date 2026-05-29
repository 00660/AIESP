# Redmi 7A pine Docker kernel handoff

## Target

- Device: Redmi 7A, codename `pine`
- ADB endpoint used: `192.168.2.103:38657`
- Current kernel observed from device: `4.9.297-perf/pine-g3ce83b96c7ea`
- Current Android userspace: Android 12 / SDK 31
- ROM identified from device properties: `PixelExtended_pine-12.0-20220227-0902-OFFICIAL`
- Boot partition observed: `/dev/block/by-name/boot -> /dev/block/mmcblk0p52`
- User stated recovery backup of the kernel already exists for rollback.

## Local files

- `current-config.gz`: raw `/proc/config.gz` pulled from the device.
- `current.config`: decompressed current kernel config.
- `config/docker-required.fragment`: Docker/container kernel option fragment.
- `scripts/build-pine-docker-kernel.sh`: Linux/GitHub Actions build script.
- `.github/workflows/build-pine-docker-kernel.yml`: manual and branch-push GitHub Actions workflow.

## Backup

- Work directory backup before edits: `android-pine-docker-kernel-20260529-090250.bak-20260529-090539`
- `.github` backup before workflow creation: `.github.bak-20260529-091223`
- Device rollback backup: user reported it was created from recovery.

## Build strategy

The Windows checkout of Xiaomi official `MiCode/Xiaomi_Kernel_OpenSource` fails because the tree contains Windows-reserved paths such as `drivers/gpu/drm/nouveau/nvkm/subdev/i2c/aux.c`. The build is therefore delegated to GitHub Actions Linux runners.

Default source in the workflow is the PixelExtended/XDA kernel source for this ROM family:

```text
https://github.com/hsx02/kernel_xiaomi_sdm439.git
branch: a12/main
defconfig: pine-perf_defconfig
arch: arm64
```

The script defaults to the device-exported `current.config`, merges Docker-required options, runs `olddefconfig`, then builds `Image.gz-dtb` and `dtbs`. This keeps the ROM's boot-tested kernel config as the baseline. To fall back to the selected kernel branch's `pine-perf_defconfig`, run with `BASE_CONFIG=` and `DEFCONFIG=pine-perf_defconfig`.

## Expected artifacts

GitHub Actions uploads an artifact named `pine-docker-kernel` containing:

- `Image.gz-dtb`
- `Image.gz`
- `dts.tar.gz`
- `config-docker-final`

The result is a kernel image, not a flashable boot image yet. Repacking requires the current matching `boot.img` or a recovery backup export.

## Notes

- `adb root` does not work on the current production build.
- Magisk exists, but normal `su` is not in `PATH`; observed root entry is `/debug_ramdisk/su`.
- Before flashing a repacked boot image, verify the final config with Docker's `check-config.sh` or `dockerd --debug` on-device.
- First GitHub Actions run `26612148198` failed because `yes "" | make olddefconfig` trips `set -o pipefail` after `olddefconfig` exits. The script now calls `make olddefconfig` directly.
- Second GitHub Actions run `26612323135` failed in `arch/arm64/kernel/vdso32` because clang used host `/usr/bin/as`, which does not accept ARM `-EL`. The script now passes `CLANG_PREFIX32=-B/usr/bin/arm-linux-gnueabi-` and `CLANG_GCC32_TC=--gcc-toolchain=/usr`.
- Third GitHub Actions run `26612499711` failed because `CLANG_PREFIX32=arm-linux-gnueabi-` was interpreted by clang as a file path.
- Fourth GitHub Actions run `26612631168` still selected host `/usr/bin/as` with `CLANG_PREFIX32=-B/usr/bin/`, so the script now uses the full binutils prefix `-B/usr/bin/arm-linux-gnueabi-`.
- Fifth GitHub Actions run `26612755663` passed the vdso32 toolchain stage but failed in `drivers/media/platform/msm/camera_v2` with `enum v4l2_mbus_pixelcode`, indicating the pulled device `current.config` does not match the selected Lineage kernel branch headers. The script now defaults to the branch defconfig and only uses `current.config` when `BASE_CONFIG` is explicitly set.
- Sixth GitHub Actions run `26613157486` still used the Lineage source and failed; the device was then identified as `PixelExtended_pine-12.0-20220227-0902-OFFICIAL`.
- Seventh GitHub Actions run `26613620370` succeeded after switching to `https://github.com/hsx02/kernel_xiaomi_sdm439.git`, branch `a12/main`, defconfig `pine-perf_defconfig`.
- Successful artifact: `pine-docker-kernel`, about 27 MB, created `2026-05-29T02:17:25Z`, expires `2026-08-27T02:05:03Z`.
- Local debug backups and downloaded run logs created during setup were removed per project preference; do not create more local backups/log dumps for this kernel debug flow.
- The Android 12 "internal problem with your device" dialog is triggered by `ActivityTaskManagerService` after `Build.isBuildConsistent()` fails. On this Treble ROM that path calls `VintfObject.verifyWithoutAvb()`, which checks runtime kernel config against framework VINTF matrices. The local Android 12 `compatibility_matrix.3.xml` for kernel `4.9.84` requires `CONFIG_FHANDLE=n`; `boot-docker-pinned.img` had `CONFIG_FHANDLE=y`, so it can boot but fail VINTF. The next build should use `current.config` as the baseline and force `CONFIG_FHANDLE` off.
- Device-config baseline build `90497b6` / GitHub Actions run `26623257355` succeeded. Artifact `pine-docker-kernel-devicebase.zip` SHA256 is `1ce602d0660b25b3b7b74ff9be135323e40ae31a53782363550da5d84ad52412`. Repacked boot is `artifacts/boot-docker-devicebase.img`, SHA256 `d387f36ed8e6e705cc68ee2aff60469a3691887cfa37cdbfe4f14c377dd26819`. TWRP-format copy is `artifacts/twrp-boot-docker-devicebase-20260529/boot.emmc.win` with matching `.sha2`. Offline matrix check against local Android 12 `compatibility_matrix.3.xml` for `4.9.84` reports `failures=0`.
