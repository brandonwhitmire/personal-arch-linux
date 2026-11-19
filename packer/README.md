# Packer — Arch base box

Build a minimal Arch Linux libvirt/QEMU Vagrant box from the official ISO.

## Prerequisites

```bash
sudo pacman -S packer
packer plugins install github.com/hashicorp/qemu
```

## Build

From repo root or this directory:

```bash
./packer/0_build.sh
# or: ./0_build.sh
```

Box: `output-arch/arch-box-libvirt-1.1.box`

Usually you do not need this — from repo root, `vagrant up` builds and registers the box via `scripts/ensure_arch_box.sh`.

```bash
vagrant box add --name arch-box --force output-arch/arch-box-libvirt-*.box   # from packer/
FORCE_BOX_BUILD=1 vagrant up   # force rebuild from repo root
```

Debug: `PACKER_LOG=1 ./0_build.sh -on-error=ask`

## Installer: `resources/arch-base.sh`

```bash
./resources/arch-base.sh --help
./resources/arch-base.sh
./resources/arch-base.sh --non-interactive \
  --disk /dev/vda --hostname myhost \
  --user vagrant --password vagrant --root-password vagrant \
  --disk-encryption mysecret
```
