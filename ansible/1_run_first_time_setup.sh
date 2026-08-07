#!/usr/bin/env bash
# Prompt for, validate, and save various Ansible configuration items.

set -euo pipefail

# --- Configuration Variables ---
ANSIBLE_BASE_DIR="$(pwd)"
ANSIBLE_INVENTORY="hosts"
ANSIBLE_VAULT_PASS_FILE=".vault_pass"
ANSIBLE_GROUP_VARS="group_vars"
ANSIBLE_GROUP_VARS_FILE="${ANSIBLE_GROUP_VARS}/all"

DELETE=false
VAULT_PASS_LENGTH=50

# --- Functions ---
usage() {
    echo "Usage: $0 [-d] [-l LENGTH]"
    echo "  -d            Force re-prompting and overwrite all configuration files."
    echo "  -l LENGTH     Length of random generated vault password (default: 50)."
    exit 1
}

# --- Argument Parsing ---
while getopts "dl:" opt; do
    case $opt in
        d) DELETE=true ;;
        l) VAULT_PASS_LENGTH="$OPTARG" ;;
        *) usage ;;
    esac
done


# --- Inventory Setup ---
if $DELETE || [ ! -f "$ANSIBLE_INVENTORY" ]; then
    echo "[*] Inventory file not found or refresh forced. Prompting for new inventory."
    read -rp "Enter default user to SSH as: " ansible_user
    echo "Enter comma-separated list of host(s) (with optional SSH port), e.g. 192.168.1.123:2222,192.168.1.125:"
    read -rp "Enter inventory: " ansible_inventory
    echo

    INVENTORY_TO_WRITE=""
    IFS=',' read -ra HOSTS <<< "$ansible_inventory"
    for socket in "${HOSTS[@]}"; do
        ip="${socket%%:*}"
        port="${socket##*:}"
        if [ "$ip" = "$port" ]; then
            port=22
        fi

        if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            IFS='.' read -ra OCTETS <<< "$ip"
            valid_ip=true
            for octet in "${OCTETS[@]}"; do
                if [[ $octet -gt 255 ]]; then
                    valid_ip=false
                    break
                fi
            done
            
            if $valid_ip; then
                INVENTORY_TO_WRITE+="$ip ansible_port=$port ansible_user=$ansible_user"$'\n'
            fi
        fi
    done
    
    if ! echo -e "$INVENTORY_TO_WRITE" > "$ANSIBLE_INVENTORY"; then
        echo "  [E] Failed to create inventory file."
        exit 1
    fi
fi

REGENERATE_SECRETS=false
if $DELETE || [ ! -f "$ANSIBLE_VAULT_PASS_FILE" ] || [ ! -f "$ANSIBLE_GROUP_VARS_FILE" ]; then
    REGENERATE_SECRETS=true
    rm -f "$ANSIBLE_VAULT_PASS_FILE" "$ANSIBLE_GROUP_VARS_FILE"
fi

if $REGENERATE_SECRETS; then
    (
        set +o pipefail
        tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "$VAULT_PASS_LENGTH" > "$ANSIBLE_VAULT_PASS_FILE"
    )
    if [ ! -s "$ANSIBLE_VAULT_PASS_FILE" ]; then
        echo "  [E] Failed to create vault password file."
        exit 1
    fi
    chmod 600 "$ANSIBLE_VAULT_PASS_FILE"

    mkdir -p "$ANSIBLE_GROUP_VARS"

    read -srp "Enter the SSH password for the remote hosts (will be encrypted): " ansible_ssh_password
    echo
    
    # Create temporary file with all variables
    cat > "$ANSIBLE_GROUP_VARS_FILE.tmp" << EOF
ansible_ssh_password: $ansible_ssh_password
ansible_become_pass: '{{ ansible_ssh_password }}'
EOF
    
    # Encrypt the entire file
    ansible-vault encrypt "$ANSIBLE_GROUP_VARS_FILE.tmp" \
        --vault-password-file "$ANSIBLE_VAULT_PASS_FILE" \
        --encrypt-vault-id default \
        --output "$ANSIBLE_GROUP_VARS_FILE"
    
    # Clean up temporary file
    rm -f "$ANSIBLE_GROUP_VARS_FILE.tmp"
fi
echo "[✓] Setup completed successfully!"
