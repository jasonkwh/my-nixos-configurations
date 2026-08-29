# Zero 2 W (bcm2710a1) ← Pi 4B (bcm2711) USB gadget link.
#
# The Zero's micro-USB OTG port plugs into a Pi 4 USB-A port (data cable).
# The Zero exposes a CDC ECM Ethernet gadget over g_ether; the Pi 4 sees a
# usb0 NIC and hands out an address over DHCP. One cable = power + network.
#
# Zero side (this host): dwc2 controller in OTG mode + g_ether module.
# Requires the dwc2 device-tree overlay (base dtb keeps the controller
# disabled) — nixos-hardware has no Zero 2 W module, so the overlay is
# declared inline, compatible with bcm2710.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  hardware.deviceTree.overlays = [
    {
      name = "dwc2-overlay";
      dtsText = ''
        /dts-v1/;
        /plugin/;

        / {
          compatible = "brcm,bcm2710";

          fragment@0 {
            target = <&usb>;
            #address-cells = <0x01>;
            #size-cells = <0x01>;

            __overlay__ {
              compatible = "brcm,bcm2835-usb";
              dr_mode = "otg";
              g-np-tx-fifo-size = <0x20>;
              g-rx-fifo-size = <0x22e>;
              g-tx-fifo-size = <0x200 0x200 0x200 0x200 0x200 0x100 0x100>;
              status = "okay";
              phandle = <0x01>;
            };
          };
        };
      '';
    }
  ];

  # g_ether (CDC ECM + RNDIS fallback) — kernel modules, loaded on boot.
  boot.kernelModules = [ "g_ether" ];

  # Static gadget-side address; the Pi 4 side is 10.55.0.1/24 (see
  # cluster/bcm2711/gadget-downlink.nix) and answers DHCP on usb0.
  networking.interfaces.usb0.ipv4.addresses = [
    {
      address = "10.55.0.2";
      prefixLength = 24;
    }
  ];
}
