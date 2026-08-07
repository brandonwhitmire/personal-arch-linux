#!/usr/bin/env bash
set -euo pipefail

# Arch Linux automated installer
# - UEFI only
# - Default: LUKS + LVM full-disk encryption
# - Optional keyring refresh (--update-keyring)
# - Enable encryption with --disk-encryption (use --luks-password to set password)
# - Interactive (default) and non-interactive (--non-interactive) for Vagrant VMs
#
# When `--non-interactive` is used, the installer additionally:
# - Enables `PasswordAuthentication yes` in `sshd_config`
# - Accepts `ssh-rsa` for initial Vagrant compatibility
# - Installs the Vagrant insecure public key to `/home/vagrant/.ssh/authorized_keys`
# - Grants passwordless sudo to the `wheel` group
# This ensures `vagrant up` can connect and Ansible (or other provisioners) can take over securely.
# Your configuration management can later harden SSH and sudo as desired.
#
# Major steps map to the official Arch Linux Installation Guide:
# https://wiki.archlinux.org/title/Installation_guide

# =========================
# Globals and defaults
# =========================
ENCRYPTION=0
LUKS_PASSWORD=""
NON_INTERACTIVE=0
UPDATE_KEYRING=0
DISK=""
HOSTNAME="arch"
USERNAME=""
USERPASS=""
ROOTPASS=""
VGNAME="vg0"
LVNAME="root"
EFI_SIZE_GIB=1

# =========================
# Helpers
# =========================
err() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "[*] $*"; }
warn() { echo "[!] $*"; }

require_root() {
  [[ $EUID -eq 0 ]] || err "Run as root."
}

require_archiso() {
  # Arch live ISO environments provide /run/archiso and boot media at /run/archiso/bootmnt.
  # Ref: common Arch ISO environment behavior.
  [[ -d /run/archiso ]] || err "This script must be run from the official Arch live environment (archiso)."
}

require_uefi() {
  # UEFI mode check per Arch Wiki ("Verify the boot mode").
  [[ -e /sys/firmware/efi/fw_platform_size ]] || err "System not booted in UEFI mode. Boot the Arch ISO in UEFI mode."
}

detect_cpu_ucode_pkg() {
  local vendor
  vendor="$(LC_ALL=C lscpu | awk -F: '/Vendor ID/ {gsub(/^[ \t]+/, "", $2); print $2}')" || true
  case "$vendor" in
    GenuineIntel) echo "intel-ucode" ;;
    AuthenticAMD) echo "amd-ucode" ;;
    *) echo "" ;;
  esac
}

confirm_or_exit() {
  local prompt="$1"
  read -r -p "$prompt [type YES to proceed]: " ans
  [[ "$ans" == "YES" ]] || err "Aborted by user."
}

prompt_secret() {
  local prompt="$1" v1 v2
  while true; do
    read -rs -p "$prompt: " v1; echo
    read -rs -p "Confirm $prompt: " v2; echo
    [[ "$v1" == "$v2" ]] && { echo "$v1"; return 0; }
    echo "Passwords do not match, try again."
  done
}

calc_swap_size_mib() {
  # Size swap roughly to RAM (cap at 8192 MiB, min 2048 MiB)
  local mem_kb
  mem_kb=$(grep -E '^MemTotal:' /proc/meminfo | awk '{print $2}')
  local mem_mib=$(( mem_kb / 1024 ))
  local size=$mem_mib
  (( size < 2048 )) && size=2048
  (( size > 8192 )) && size=8192
  echo "$size"
}

# =========================
# Arg parsing
# =========================
print_usage() {
  cat <<EOF
Usage: $0 [options]

Modes:
  --non-interactive              Run fully automated using provided flags.
Options:
  --disk /dev/sdX|/dev/nvme0n1  Target disk (optional, will auto-detect if not specified).
  --hostname NAME               Hostname.
  --user NAME                   Non-root user (default: prompt in interactive; 'vagrant' in non-interactive).
  --password PASS               Password for non-root user (default: prompt; 'vagrant' in non-interactive).
  --root-password PASS          Root password (default: prompt; 'vagrant' in non-interactive).
  --disk-encryption             Enable LUKS + LVM with optional password (encryption disabled by default).
  --luks-password PASS          LUKS password (default: prompt; 'vagrant' in non-interactive).
  -u, --update-keyring          Refresh archlinux-keyring before install.
  -h, --help                    Show this help.

Defaults for --non-interactive:
  user=$USERNAME, password=$USERPASS, root password=$ROOTPASS, luks password=$LUKS_PASSWORD, hostname=$HOSTNAME
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --non-interactive) NON_INTERACTIVE=1; shift ;;
    --disk) DISK="${2:-}"; shift 2 ;;
    --hostname) HOSTNAME="${2:-}"; shift 2 ;;
    --user) USERNAME="${2:-}"; shift 2 ;;
    --password) USERPASS="${2:-}"; shift 2 ;;
    --root-password) ROOTPASS="${2:-}"; shift 2 ;;
    --disk-encryption) 
      ENCRYPTION=1
      shift
      ;;
    --luks-password)
      LUKS_PASSWORD="${2:-}"
      shift 2
      ;;
    -u|--update-keyring) UPDATE_KEYRING=1; shift ;;
    -h|--help) print_usage; exit 0 ;;
    *) err "Unknown arg: $1" ;;
  esac
done

# Automatic disk detection if not specified
if [[ -z "$DISK" ]]; then
  info "No disk specified, auto-detecting..."
  DISK_HELPER=$(lsblk --paths --output NAME,TYPE --sort NAME | grep disk | awk '{print $1}' | grep -E 'vd[a-z]$|sd[a-z]$|hd[a-z]$|nvme[0-9]+n[0-9]+$' | sort --reverse | tail -n1)
  [[ -n "$DISK_HELPER" ]] || err "No valid disk found for auto-detection"
  DISK="$DISK_HELPER"
  info "Auto-detected disk: $DISK"
fi

# Non-interactive defaults
if (( NON_INTERACTIVE )); then
  : "${USERNAME:=vagrant}"
  : "${USERPASS:=vagrant}"
  : "${ROOTPASS:=vagrant}"
  : "${LUKS_PASSWORD:=vagrant}"
fi

# Interactive prompts
if (( ! NON_INTERACTIVE )); then
  info "Interactive mode."
  lsblk -dpno NAME,SIZE,TYPE | grep -E 'disk$' || true
  info "Using disk: $DISK"
  [[ -b "$DISK" ]] || err "Disk not found: $DISK"
  read -r -p "Hostname [$HOSTNAME]: " _h; HOSTNAME="${_h:-$HOSTNAME}"
  read -r -p "Create non-root username: " USERNAME
  [[ -n "$USERNAME" ]] || err "Username cannot be empty."

  warn "This will WIPE ALL DATA on $DISK and install Arch Linux."
  confirm_or_exit "Final confirmation"
  if (( ENCRYPTION )); then
    info "Full-disk encryption is ENABLED. Use --luks-password to set password."
    if [[ -z "$LUKS_PASSWORD" ]]; then
      LUKS_PASSWORD="$(prompt_secret "LUKS encryption password")"
    fi
  else
    info "Full-disk encryption is DISABLED by default. Use --disk-encryption to enable."
  fi

  USERPASS="$(prompt_secret "Password for user '$USERNAME'")"
  ROOTPASS="$(prompt_secret "Password for root")"
fi

require_root
require_archiso
require_uefi

# Ensure network time sync per guide
timedatectl set-ntp true

# Optional keyring refresh before pacstrap
if (( UPDATE_KEYRING )); then
  info "Refreshing archlinux-keyring..."
  pacman -Sy --noconfirm archlinux-keyring
fi

# =========================
# Partitioning (destructive)
# =========================
info "Partitioning disk $DISK (GPT, EFI ${EFI_SIZE_GIB} GiB, root rest)..."
# Zap and create GPT
sgdisk --zap-all "$DISK"
partprobe "$DISK" || true

# Create partitions:
# 1: EFI System Partition, 1 GiB, type ef00
# 2: Linux filesystem, rest of disk, type 8300
sgdisk -n 1:0:+${EFI_SIZE_GIB}G -t 1:ef00 -c 1:"EFI System Partition" "$DISK"
sgdisk -n 2:0:0 -t 2:8300 -c 2:"Linux filesystem" "$DISK"
partprobe "$DISK" || true

# Resolve partition paths for sdX vs nvme
if [[ "${DISK}" = *nvme* ]] ; then
    # nvmeXnXpX format
    P1="${DISK}p1"
    P2="${DISK}p2"
else
    # sdX or vda format
    P1="${DISK}1"
    P2="${DISK}2"
fi

# Filesystems
info "Formatting EFI partition $P1 as FAT32..."
mkfs.fat -F32 "$P1"

# =========================
# Encryption + LVM (default)
# =========================
ROOT_MAPPER=""
if (( ENCRYPTION )); then
  info "Setting up LUKS2 on $P2 and LVM inside it..."
  # LUKS2 container
  echo -n "${LUKS_PASSWORD}" | cryptsetup luksFormat --type luks1 --force-password "$P2" -
  echo -n "${LUKS_PASSWORD}" | cryptsetup open "$P2" cryptroot
  # LVM inside
  pvcreate /dev/mapper/cryptroot
  vgcreate "$VGNAME" /dev/mapper/cryptroot
  lvcreate -l 100%FREE -n "$LVNAME" "$VGNAME"
  mkfs.ext4 "/dev/${VGNAME}/${LVNAME}"
  ROOT_DEV="/dev/${VGNAME}/${LVNAME}"
  ROOT_MAPPER="/dev/mapper/${VGNAME}-${LVNAME}"
else
  info "Creating unencrypted ext4 on $P2..."
  mkfs.ext4 -F "$P2"
  ROOT_DEV="$P2"
  ROOT_MAPPER="$P2"
fi

# =========================
# Mounting
# =========================
info "Mounting target system..."
mount "$ROOT_DEV" /mnt
mkdir -p /mnt/boot
mount "$P1" /mnt/boot

# =========================
# Base system installation
# =========================
UCODE="$(detect_cpu_ucode_pkg)"
PKGS=(base base-devel linux linux-headers linux-firmware lvm2 networkmanager iwd vim openssh python grub efibootmgr)
if [[ -n "$UCODE" ]]; then PKGS+=("$UCODE"); fi

info "Installing base system with pacstrap..."
pacstrap -K /mnt "${PKGS[@]}"

info "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# =========================
# System configuration in chroot
# =========================
arch-chroot /mnt /bin/bash -euxo pipefail <<CHROOT
# Locale
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

# Timezone and clock
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc

# Pacman ParallelDownloads
# Arch Wiki: enable ParallelDownloads option in pacman.conf for faster downloads.
if grep -q '^[# ]*ParallelDownloads' /etc/pacman.conf; then
  sed -i 's/^[# ]*ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf
else
  echo 'ParallelDownloads = 5' >> /etc/pacman.conf
fi

# Hostname and hosts
echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1 localhost" > /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 ${HOSTNAME}.localdomain ${HOSTNAME}" >> /etc/hosts

# Root password
echo "root:${ROOTPASS}" | chpasswd

# Create user and set password
useradd -m -G wheel -s /bin/bash "${USERNAME}"
echo "${USERNAME}:${USERPASS}" | chpasswd

# Secure sudo via /etc/sudoers.d
if [[ "${NON_INTERACTIVE}" -eq 1 ]]; then
  # Passwordless sudo for Vagrant provisioning
  echo '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/10-wheel
else
  # Password required for interactive installations
  echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel
fi
chmod 440 /etc/sudoers.d/10-wheel

# Secure sshd defaults: disable root login, allow password auth for vagrant/ansible
sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Allow ssh-rsa algorithm for Vagrant's default insecure key
echo 'PubkeyAcceptedAlgorithms +ssh-rsa' >> /etc/ssh/sshd_config
echo 'HostkeyAlgorithms +ssh-rsa' >> /etc/ssh/sshd_config

# Setup Vagrant insecure key for non-interactive builds
if [[ "${NON_INTERACTIVE}" -eq 1 ]]; then
  mkdir -p /home/vagrant/.ssh
  curl -fsSL https://raw.githubusercontent.com/hashicorp/vagrant/main/keys/vagrant.pub -o /home/vagrant/.ssh/authorized_keys
  chown -R vagrant:vagrant /home/vagrant/.ssh
  chmod 700 /home/vagrant/.ssh
  chmod 600 /home/vagrant/.ssh/authorized_keys
fi

# Enable services
systemctl enable NetworkManager
systemctl enable sshd
CHROOT

# =========================
# Initramfs hooks and bootloader
# =========================
if (( ENCRYPTION )); then
  # Add encrypt and lvm2 hooks, preserve typical defaults and order.
  arch-chroot /mnt /bin/bash -euxo pipefail <<'CHROOT'
  sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt lvm2 filesystems fsck)/' /etc/mkinitcpio.conf
  mkinitcpio -P
CHROOT
else
  arch-chroot /mnt /bin/bash -euxo pipefail <<'CHROOT'
  sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)/' /etc/mkinitcpio.conf
  mkinitcpio -P
CHROOT
fi

# Configure GRUB cmdline and install
if (( ENCRYPTION )); then
  # cryptdevice needs UUID of the LUKS partition (P2), not the LV.
  LUKS_UUID="$(blkid -s UUID -o value "$P2")"
  arch-chroot /mnt /bin/bash -euxo pipefail <<CHROOT
  sed -i 's/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="cryptdevice=UUID=${LUKS_UUID}:cryptroot root=\\/dev\\/mapper\\/${VGNAME}-${LVNAME}"/' /etc/default/grub
  sed -i 's/^#\?GRUB_ENABLE_CRYPTODISK=.*/GRUB_ENABLE_CRYPTODISK=y/' /etc/default/grub
CHROOT
else
  ROOT_UUID="$(blkid -s UUID -o value "$P2")"
  arch-chroot /mnt /bin/bash -euxo pipefail <<CHROOT
  sed -i 's/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="root=UUID=${ROOT_UUID}"/' /etc/default/grub
CHROOT
fi

arch-chroot /mnt /bin/bash -euxo pipefail <<'CHROOT'
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --removable
grub-mkconfig -o /boot/grub/grub.cfg
CHROOT

# =========================
# Swapfile
# =========================
SWAP_MIB="$(calc_swap_size_mib)"
info "Creating ${SWAP_MIB} MiB swapfile..."
arch-chroot /mnt /bin/bash -euxo pipefail <<CHROOT
fallocate -l ${SWAP_MIB}M /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap defaults 0 0' >> /etc/fstab
CHROOT

# =========================
# Done
# =========================
info "Installation complete."
info "You can now: umount -R /mnt  &&  swapoff -a  &&  reboot"