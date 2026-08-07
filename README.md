# personal-arch-linux

Arch Linux daily driver: Packer base image → Ansible desktop → Vagrant e2e.

Merged from [personal-packer](https://github.com/brandonwhitmire/personal-packer) and [personal-ansible](https://github.com/brandonwhitmire/personal-ansible). Provider: **libvirt + QEMU**.

## Quick start (repo root)

`vagrant up` builds the Packer box if missing, registers it, boots the VM, and runs Ansible:

```bash
# one-time: Ansible on PATH
cd ansible && python3 -m venv venv && source venv/bin/activate
pip3 install -r requirements.txt
ansible-galaxy collection install -r requirements.yml
cd ..

source ansible/venv/bin/activate
vagrant up
```

Rebuild base box: `FORCE_BOX_BUILD=1 vagrant up`  
Halt / destroy: `vagrant halt` · `vagrant destroy`

## Manual Packer build (optional)

```bash
./packer/0_build.sh
vagrant box add --name arch-box --force packer/output-arch/arch-box-libvirt-*.box
```

Box path: `packer/output-arch/arch-box-libvirt-1.1.box`  
Debug Packer: `PACKER_LOG=1 ./packer/0_build.sh -on-error=ask`

## Ansible against real hosts

```bash
cd ansible
source venv/bin/activate
./1_run_first_time_setup.sh
ansible-playbook archlinux.yml
```

See `ansible/README.md` and `packer/README.md`.
