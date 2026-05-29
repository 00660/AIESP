# Redmi 5A riva Docker kernel handoff

## Target

- Device: Redmi 5A, codename `riva`, ROM device family `rova`.
- ADB endpoint used: `192.168.2.156:5555`.
- ROM observed from properties: `crDroidAndroid-14.0-20241015-rova-v10.9`.
- Running kernel: `4.19.318-4.5-iusmac-Mi8937v2-Mi8917-ga5f398b25ebd`.
- Boot partition: `/dev/block/by-name/boot -> /dev/block/mmcblk0p21`, size `67108864`.
- Root verified through Magisk: `uid=0(root) gid=0(root) context=u:r:magisk:s0`.

## Source Origin

- XDA thread: `https://xdaforums.com/t/rom-14-0-official-non-rdp-rolex-riva-crdroid-10-x.4669720/`
- ROM download family: `https://sourceforge.net/projects/crdroid/files/rova/10.x/`
- Kernel source: `https://github.com/crdroidandroid/android_kernel_xiaomi_rova`
- Selected branch: `14.0`
- Branch head observed locally: `433ac75e5124689d09c58cb08e7a944d7b91834b`

## Local Backups

- Current boot image: `boot-current.img`
- Current config: `current.config`
- Current config gzip: `current-config.gz`
- SHA256:
  - `boot-current.img`: `1AA32E143DA79E16F4961B45BD2513CAA68F3E4F8751ECF710824E86E59F8947`
  - `current.config`: `15BD2E2B75D75BCA86C307B86178B943E40ABA01906FE56410C672E6739502BC`
  - `current-config.gz`: `98C557EEFE098E671BE992836E5FF2136B2B02E56521AE0A21C741C387325E80`

## Docker Config Work

- Current config already has `CONFIG_OVERLAY_FS=y`, `CONFIG_VETH=y`, `CONFIG_NET_NS=y`, `CONFIG_MEMCG=y`, `CONFIG_CGROUP_BPF=y`, `CONFIG_BPF_SYSCALL=y`.
- Current missing Docker options include:
  - `CONFIG_SYSVIPC`
  - `CONFIG_POSIX_MQUEUE`
  - `CONFIG_CGROUP_PIDS`
  - `CONFIG_CGROUP_DEVICE`
  - `CONFIG_PID_NS`
  - `CONFIG_BRIDGE_NETFILTER`
  - `CONFIG_NETFILTER_XT_MATCH_ADDRTYPE`
  - `CONFIG_MACVLAN`
- Added fragment: `config/docker-required.fragment`.
- Added build script: `scripts/build-riva-docker-kernel.sh`.
- Added workflow: `.github/workflows/build-riva-docker-kernel.yml`.
- GitHub Actions branch pushed: `riva-docker-kernel`.
- First run: `https://github.com/00660/AIESP/actions/runs/26644172502`.

## Notes

- Do not reuse `pine` boot images on this device. This target is `riva/rova` with MSM8937 and Linux 4.19.
- Windows checkout of the kernel tree fails on reserved path `drivers/gpu/drm/nouveau/nvkm/subdev/i2c/aux.c`; build must run on Linux/GitHub Actions.
- A temporary Docker runtime zip push to `/data/local/tmp` was stopped before install. No Docker runtime install or boot flashing was performed in this pass.
