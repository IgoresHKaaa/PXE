packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.9"
      source  = "github.com/hashicorp/qemu"
    }
    ansible = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

variable "vm_name" { type = string; default = "pxe-server-01" }
variable "netbox_ip" { type = string; default = "192.168.1.10/24" } 
variable "netbox_gateway" { type = string; default = "192.168.1.1" }
variable "netbox_dns" { type = string; default = "8.8.8.8" }

locals {
  ip_address = regex_replace(var.netbox_ip, "/.*", "")
  ip_cidr    = regex_replace(var.netbox_ip, ".*/", "")
}

source "qemu" "debian13_pxe" {
  iso_checksum      = "sha256:YOUR_DEBIAN_13_NETINST_ISO_SHA256"
  iso_url           = "https://cdimage.debian.org/cdimage/weekly-builds/amd64/iso-cd/debian-testing-amd64-netinst.iso"
  shutdown_command  = "sudo shutdown -P now"
  ssh_username      = "root"
  ssh_password      = "packer"
  ssh_timeout       = "20m"
  vm_name           = "${var.vm_name}.qcow2"
  disk_size         = "20G"
  format            = "qcow2"
  accelerator       = "kvm"
  net_device        = "virtio-net"
  disk_interface    = "virtio"
  boot_wait         = "5s"
  
  http_directory    = "http"
  
  boot_command      = [
    "<esc><wait>",
    "install auto=true priority=critical ",
    "netcfg/get_ipaddress=${local.ip_address} ",
    "netcfg/get_netmask=${local.ip_cidr} ", 
    "netcfg/get_gateway=${var.netbox_gateway} ",
    "netcfg/get_nameservers=${var.netbox_dns} ",
    "preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg <enter>"
  ]
}

build {
  sources = ["source.qemu.debian13_pxe"]

  provisioner "ansible" {
    playbook_file = "../playbooks/provision_pxe.yml"
    user          = "root"
    extra_arguments = [
      "--extra-vars", "pxe_device_name=${var.vm_name} pxe_interface_name=eth0"
    ]
  }
}