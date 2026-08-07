# Ansible — Arch daily driver

Idempotent playbooks that turn a minimal Arch install into the desktop environment.

Run all commands from this directory (`ansible/`).

## Setup

```bash
sudo pacman -S --noconfirm sshpass
python3 -m venv venv && source venv/bin/activate
pip3 install --requirement requirements.txt
ansible-galaxy collection install --requirements-file requirements.yml
./1_run_first_time_setup.sh   # inventory + vault
```

Target: enable SSH (`sudo systemctl enable --now sshd`). Optional: `ssh-copy-id`.

## Run

```bash
source venv/bin/activate
ansible-playbook archlinux.yml
```

## Verify

```bash
ansible-playbook --syntax-check archlinux.yml
ansible-lint
ansible-playbook --check archlinux.yml
```

## Common commands

```bash
ansible-inventory --list
ansible-inventory --graph

ansible-playbook --check -vvvvv archlinux.yml

ansible all -m debug -a "var=hostvars"
```

Ad-hoc (no inventory file; trailing comma required):

```bash
ANSIBLE_INVENTORY_ENABLED="host_list" ansible-playbook \
  --inventory <HOST>, \
  --extra-vars "ansible_ssh_extra_args='-o StrictHostKeyChecking=no' ansible_user=<USER> ansible_ssh_password=<PASSWORD> ansible_ssh_become_password=<PASSWORD>" \
  archlinux.yml
```

## End-to-end (Vagrant)

From **repo root** (Packer builds `arch-box` automatically if missing):

```bash
source ansible/venv/bin/activate
vagrant up
vagrant halt
vagrant destroy
```

Force Packer rebuild: `FORCE_BOX_BUILD=1 vagrant up`

## Troubleshooting

- Stay in `ansible/` so `ansible.cfg` resolves correctly.
- Task debugger: `ANSIBLE_ENABLE_TASK_DEBUGGER=True`
- Vagrant SSH issues: check `vagrant.out` / `vagrant.err`
