#!/bin/bash
#
# This script is executed by Packer on the live Arch ISO.
# It idempotently configures a 'vagrant' user and enables SSH.

set -euxo pipefail # Exit on error, print commands, fail on unset variables

# --- Configuration ---
readonly TEMP_SSH_USER="vagrant"
readonly TEMP_SSH_PASSWORD="vagrant"

# --- Main Logic ---

echo "==> Ensuring network is available..."
until ping -c 1 1.1.1.1 &>/dev/null; do
    echo "Network not ready, sleeping for 2 seconds..."
    sleep 2
done

echo "==> Creating user '${TEMP_SSH_USER}' if they do not exist..."
# This is the idempotent check.
if ! id -u "${TEMP_SSH_USER}" &>/dev/null; then
    useradd --comment "${TEMP_SSH_USER}" --create-home --user-group "${TEMP_SSH_USER}"
    echo "User '${TEMP_SSH_USER}' created."
else
    echo "User '${TEMP_SSH_USER}' already exists."
fi

echo "==> Setting password for '${TEMP_SSH_USER}'..."
echo "${TEMP_SSH_USER}:${TEMP_SSH_PASSWORD}" | chpasswd --crypt-method SHA512

echo "==> Configuring passwordless sudo for '${TEMP_SSH_USER}'..."
# Ensure we create a clean sudoers file.
echo "${TEMP_SSH_USER} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/10-vagrant
chmod 0440 /etc/sudoers.d/10-vagrant
visudo --check --strict

echo "==> Installing and enabling SSH daemon..."
if ! command -v pacman &> /dev/null; then
    echo "ERROR: pacman not found; this script expects the Arch live ISO" >&2
    exit 1
fi

echo "==> Detected Arch Linux, using pacman..."
pacman -Syy --noconfirm --needed openssh
SSH_SERVICE="sshd.service"

# Configure sshd for Packer's use case.
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config

# Ensure the service is started and enabled.
systemctl enable --now "${SSH_SERVICE}"

echo "==> SSH setup complete. Packer should be able to connect."
