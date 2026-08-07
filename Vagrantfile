# frozen_string_literal: true

require "fileutils"

REPO_ROOT = __dir__
BOX_NAME = "arch-box"
BOX_GLOB = File.join(REPO_ROOT, "packer", "output-arch", "arch-box-libvirt-*.box")

OVMF_CODE = "/usr/share/edk2/x64/OVMF_CODE.4m.fd"
# Prefer system template; fall back to vendored copy (Arch package file is often missing).
OVMF_VARS_CANDIDATES = [
  "/usr/share/edk2/x64/OVMF_VARS.4m.fd",
  File.join(REPO_ROOT, "packer", "resources", "OVMF_VARS.4m.fd"),
].freeze
NVRAM_FILE = File.join(REPO_ROOT, ".vagrant", "nvram", "arch-box_VARS.fd")

def ovmf_vars_template
  OVMF_VARS_CANDIDATES.find { |p| File.exist?(p) }
end

# System qemu cannot enter a private $HOME (mode 710) without an ACL — file chmod
# alone never fixes that. Allow traverse for both common qemu users (portable).
def ensure_home_traversable_for_qemu!
  home = ENV.fetch("HOME")
  %w[libvirt-qemu qemu].each do |user|
    next unless system("getent", "passwd", user, out: File::NULL, err: File::NULL)

    system("setfacl", "-m", "u:#{user}:--x", home)
  end
end

# Build + register the Packer box before Vagrant looks for it.
# Skip for non-up commands (status, ssh, halt, …). Rebuild: FORCE_BOX_BUILD=1 vagrant up
if ARGV.include?("up")
  ok = system({"FORCE_BOX_BUILD" => ENV.fetch("FORCE_BOX_BUILD", "0")},
              "bash", File.join(REPO_ROOT, "scripts", "ensure_arch_box.sh"))
  abort("Failed to ensure #{BOX_NAME} (Packer build / vagrant box add)") unless ok

  template = ovmf_vars_template
  abort(<<~MSG) unless template
    Missing OVMF_VARS template. Restore with:
      sudo pacman -S edk2-ovmf
    or ensure packer/resources/OVMF_VARS.4m.fd exists.
  MSG
  FileUtils.mkdir_p(File.dirname(NVRAM_FILE))
  unless File.exist?(NVRAM_FILE)
    FileUtils.cp(template, NVRAM_FILE)
    # qemu opens NVRAM read-write and may take ownership after first boot.
    File.chmod(0o666, NVRAM_FILE)
  end
  ensure_home_traversable_for_qemu!
end

Vagrant.configure("2") do |config|
  config.vm.define "archlinux", primary: true do |archlinux|
    archlinux.vm.box = BOX_NAME
    archlinux.vm.box_check_update = false
    archlinux.vm.hostname = "ansible-test-arch"

    # Prefer the newest local artifact if present (after Packer build).
    local_boxes = Dir[BOX_GLOB]
    if local_boxes.any?
      newest = local_boxes.max_by { |f| File.mtime(f) }
      archlinux.vm.box_url = "file://#{newest}"
    end

    archlinux.vm.provider "libvirt" do |libvirt|
      libvirt.memory = "4096"
      libvirt.cpus = "2"
      libvirt.machine_type = "q35"
      libvirt.loader = OVMF_CODE
      libvirt.nvram = NVRAM_FILE
    end

    archlinux.vm.provision "ansible" do |ansible|
      ansible.compatibility_mode = "2.0"
      ansible.become = true
      ansible.become_user = "root"
      ansible.verbose = false
      ansible.playbook = "ansible/archlinux.yml"
      ansible.config_file = "ansible/ansible.cfg"
    end
  end
end
