#!/usr/bin/env bash
# Ensure the Arch Vagrant box exists: register a local .box, or Packer-build if missing.
# Invoked by Vagrantfile on `vagrant up`. Safe to run from repo root.
#
# Env:
#   FORCE_BOX_BUILD=1  rebuild with Packer even if a .box / registered box exists
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOX_NAME="arch-box"
BOX_GLOB="${ROOT}/packer/output-arch/arch-box-libvirt-*.box"
VAULT_PASS="${ROOT}/ansible/.vault_pass"

# ansible.cfg always references .vault_pass; stub is enough for Vagrant e2e.
if [[ ! -f "${VAULT_PASS}" ]]; then
  printf 'vagrant-e2e\n' > "${VAULT_PASS}"
  chmod 600 "${VAULT_PASS}"
  echo "==> Created stub ansible/.vault_pass for Vagrant provisioning"
fi

box_present() {
  vagrant box list 2>/dev/null | awk '{print $1}' | grep -qx "${BOX_NAME}"
}

latest_box() {
  # Prefer real files over broken symlinks; newest mtime wins.
  # shellcheck disable=SC2086
  local f
  for f in ${BOX_GLOB}; do
    [[ -e "${f}" ]] || continue
    echo "${f}"
  done | xargs -r ls -1t 2>/dev/null | head -n1 || true
}

register_box() {
  local box_file="$1"
  echo "==> Registering Vagrant box '${BOX_NAME}' from ${box_file}"
  vagrant box add --name "${BOX_NAME}" --force "${box_file}"
}

BOX_FILE="$(latest_box)"

if [[ "${FORCE_BOX_BUILD:-0}" == "1" ]]; then
  echo "==> FORCE_BOX_BUILD=1 — rebuilding with Packer..."
  BOX_FILE=""
elif box_present; then
  echo "==> Vagrant box '${BOX_NAME}' already present; skipping Packer build."
  echo "    Rebuild with: FORCE_BOX_BUILD=1 vagrant up"
  exit 0
elif [[ -n "${BOX_FILE}" ]]; then
  echo "==> Found local box artifact; registering (no Packer rebuild)."
  register_box "${BOX_FILE}"
  exit 0
fi

echo "==> Building '${BOX_NAME}' with Packer (this can take a while)..."
if ! packer plugins installed 2>/dev/null | grep -qi qemu; then
  packer plugins install github.com/hashicorp/qemu
fi
"${ROOT}/packer/0_build.sh"

BOX_FILE="$(latest_box)"
if [[ -z "${BOX_FILE}" || ! -e "${BOX_FILE}" ]]; then
  echo "ERROR: Packer finished but no box matched ${BOX_GLOB}" >&2
  exit 1
fi

register_box "${BOX_FILE}"
echo "==> Ready: vagrant up"
