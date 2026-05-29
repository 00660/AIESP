# Redmi 7A pine Docker kernel handoff

## Target

- Device: Redmi 7A, codename `pine`
- ADB endpoint used: `192.168.2.103:38657`
- Current kernel observed from device: `4.9.297-perf/pine-g3ce83b96c7ea`
- Current Android userspace: Android 12 / SDK 31
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

Default source in the workflow is:

```text
https://github.com/LineageOS/android_kernel_xiaomi_msm8937.git
branch: lineage-19.1
defconfig: msm8937-perf_defconfig
arch: arm64
```

The script uses the device's `current.config` as the base config, merges Docker-required options, runs `olddefconfig`, then builds `Image.gz-dtb` and `dtbs`.

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
