packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

locals {
  arch_box_name      = "arch-box"
  arch_box_version   = "1.1"
  arch_box_provider  = "libvirt"
  arch_output_dir    = "output-arch"
  arch_disk_size_gib = 40
}

source "qemu" "arch" {
  cpus      = 2
  memory    = 4096
  disk_size = local.arch_disk_size_gib * 1024
  headless  = false
  # US
  #iso_url           = "https://mirrors.edge.kernel.org/archlinux/iso/latest/archlinux-x86_64.iso"
  #iso_checksum      = "file:https://mirrors.edge.kernel.org/archlinux/iso/latest/sha256sums.txt"
  # Mexico
  iso_url           = "https://arch.jsc.mx/iso/latest/archlinux-x86_64.iso"
  iso_checksum      = "file:https://arch.jsc.mx/iso/latest/sha256sums.txt"
  http_directory    = ".."
  efi_boot          = true
  efi_firmware_code = "/usr/share/edk2/x64/OVMF_CODE.4m.fd"
  # Vendored template — system /usr/share/edk2/x64/OVMF_VARS.4m.fd is often missing on Arch.
  efi_firmware_vars = "resources/OVMF_VARS.4m.fd"
  #"<wait10s>", "fs0:\\efi\\boot\\bootx64.efi", "<enter>", "<wait5s>", "<enter>", "<wait45s>",
  boot_command = [
    "<wait5>", "<enter>",
    "curl -fsSL http://{{ .HTTPIP }}:{{ .HTTPPort }}/packer/resources/enable-ssh.sh | bash", "<enter>"
  ]
  boot_wait        = "2m"
  shutdown_command = "echo 'vagrant' | sudo -S shutdown -P now"
  shutdown_timeout = "10m"
  communicator     = "ssh"
  ssh_username     = "vagrant"
  ssh_password     = "vagrant"
  ssh_timeout      = "30m"
  vm_name          = "box"
  output_directory = local.arch_output_dir
  format           = "qcow2"
}

build {
  sources = ["source.qemu.arch"]

  provisioner "shell" {
    execute_command = "echo 'vagrant' | sudo -S -E bash -c '{{ .Vars }} {{ .Path }} --non-interactive'"
    script          = "resources/arch-base.sh"
  }

  post-processor "vagrant" {
    output              = "${local.arch_output_dir}/${local.arch_box_name}-${local.arch_box_provider}-${local.arch_box_version}.box"
    architecture        = "amd64"
    compression_level   = 6
    keep_input_artifact = true
  }
}
