#!/bin/bash
# Share /home/shared with the shared-data group.
# Directories are group-writable and setgid. Other users can enter them but
# cannot write, and new files inherit the group without becoming executable
# or world-writable. Existing executable bits are left in place, except on
# Ansible vault password files, which must not be executable.

set -euo pipefail

root=${1:-/home/shared}
changed=0

if find "$root" -xdev -type d \( ! -group shared-data -o ! -perm 2775 \) -print -quit | grep -q .; then
    find "$root" -xdev -type d \( ! -group shared-data -o ! -perm 2775 \) \
        -exec chgrp shared-data {} + \
        -exec chmod 2775 {} +
    changed=1
fi

# One getfacl walk. Any default ACL that still grants other write is replaced.
if getfacl -Rdc "$root" 2>/dev/null | awk '/^other::/ && $0 != "other::r-x" { found = 1; exit } END { exit !found }'; then
    find "$root" -xdev -type d -exec setfacl -m d:u::rwx,d:g::rwx,d:o::r-x {} +
    changed=1
fi

if find "$root" -xdev -type f \( ! -group shared-data -o ! -perm -g+rw -o -perm -002 \) -print -quit | grep -q .; then
    find "$root" -xdev -type f \( ! -group shared-data -o ! -perm -g+rw -o -perm -002 \) \
        -exec chgrp shared-data {} + \
        -exec chmod g+rw,o-w {} +
    changed=1
fi

if find "$root" -xdev -type f -name .vault_pass -perm /111 -print -quit | grep -q .; then
    find "$root" -xdev -type f -name .vault_pass -perm /111 \
        -exec chgrp shared-data {} + \
        -exec chmod a-x,ug+rw,o-w {} +
    changed=1
fi

if [ "$changed" -eq 1 ]; then
    printf 'changed\n'
fi
