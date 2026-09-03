# Zero 2 W (bcm2710a1) ← Pi 4B (bcm2711) USB gadget link.
#
# The Zero's micro-USB OTG port plugs into a Pi 4 USB-A port (data cable).
# The Zero exposes a CDC ECM Ethernet gadget over g_ether; the Pi 4 sees a
# usb0 NIC and provides network access. One cable = power + network.
#
# Zero side (this host): dwc2 controller in OTG mode + g_ether module.
# Requires the dwc2 device-tree overlay because the base DTB keeps the
# controller disabled.
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

  boot.kernelModules = [ "g_ether" ];
  boot.extraModprobeConfig = ''
    options g_ether host_addr=02:55:00:00:00:01 dev_addr=02:55:00:00:00:02
  '';

  # Static gadget-side address; the Pi 4 side is 10.55.0.1/24.
  networking.interfaces.usb0.ipv4.addresses = [
    {
      address = "10.55.0.2";
      prefixLength = 24;
    }
  ];
}
