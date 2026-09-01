# RPi 4B (BCM2711) hardware layout for the SD-card image.
# Board firmware/DTB/boot-partition handling comes from
# nixos-hardware.nixosModules.raspberry-pi-4; this file only covers mounts.
{ config, lib, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };

  # all-hardware profile (via sd-image.nix) lists dw-hdmi for Rockchip; rpi kernel has no such module, so modprobe fails and the image build dies.
  boot.initrd.availableKernelModules = lib.mkForce [
    "ahci" "ata_piix" "autofs" "efivarfs" "ehci_hcd" "ehci_pci" "ext2" "ext4"
    "hid_apple" "hid_cherry" "hid_corsair" "hid_generic" "hid_lenovo"
    "hid_logitech_dj" "hid_logitech_hidpp" "hid_microsoft" "hid_roccat"
    "mmc_block" "nvme" "ohci_hcd" "ohci_pci" "pata_marvell" "pcie-brcmstb"
    "reset-raspberrypi" "sata_nv" "sata_sis" "sata_uli" "sata_via" "sd_mod"
    "sr_mod" "uhci_hcd" "usb-storage" "usbhid" "vc4" "xhci_hcd" "xhci_pci"
  ];

  fileSystems."/boot/firmware" = {
    device = "/dev/disk/by-label/FIRMWARE";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  swapDevices = [ ]; # zramSwap instead — see common/headless.nix

  # Enables DHCP on each ethernet and wireless interface.
  networking.useDHCP = lib.mkDefault true;
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";
}
