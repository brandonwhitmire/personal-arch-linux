#!/usr/bin/env bash
set -euo pipefail

# Always run from this script's directory so paths work from repo root or packer/.
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Prefer a home cache for Packer scratch space (large qcow2 builds).
TMPDIR_DEFAULT="${HOME}/.cache/packer/"
mkdir -p "${TMPDIR_DEFAULT}"
export TMPDIR="${TMPDIR:-${TMPDIR_DEFAULT}}"

packer build . "$@"
