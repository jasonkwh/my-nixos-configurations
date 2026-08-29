# Pi 4B (bcm2711) downlink to the Zero 2 W (bcm2710a1) USB gadget link.
#
# A Pi USB-A port feeds the Zero's micro-USB OTG port (power + data in one
# cable). The Zero runs g_ether (CDC ECM); this host sees it as usb0 and
# answers DHCP so the Zero gets 10.55.0.2/24 without any config drift.
# Requires the dwc2 overlay (host side of the link) — same module shape as
# nixos-hardware's raspberry-pi-4 dwc2, but declared here since we do not
# import that module's per-feature options.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  linkNet = "10.55.0.0/24";
in
{
  hardware.deviceTree.overlays = [
    {
      name = "dwc2-overlay";
      dtsText = ''
        /dts-v1/;
        /plugin/;

        / {
          compatible = "brcm,bcm2711";

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

  # Host-side NIC + DHCP serving.
  networking.interfaces.usb0.ipv4.addresses = [
    {
      address = "10.55.0.1";
      prefixLength = 24;
    }
  ];
  services.dnsmasq = {
    enable = true;
    # Scoped strictly to the gadget link; upstream DNS comes from
    # networking.nameservers via resolvconf, so only serve DHCP here.
    settings = {
      interface = "usb0";
      bind-interfaces = true;
      dhcp-range = [ "10.55.0.2,10.55.0.2,12h" ];
      no-resolv = true;
      no-hosts = true;
      port = 0; # DNS off, DHCP only
    };
  };

  # The Zero reaches the tailnet through this host: NAT the link out the
  # uplink interfaces (wlan0 / tailscale0).
  networking.nat = {
    enable = true;
    internalInterfaces = [ "usb0" ];
    externalInterface = "wlan0";
    forwardPorts = [ ];
  };
  boot.kernel.sysctl."net.ipv4.ip_forward" = lib.mkForce 1;
  networking.firewall.trustedInterfaces = [ "usb0" ];
  networking.firewall.extraInputRules = ''
    iifname "usb0" udp dport 67 accept comment "gadget DHCP"
  '';
  networking.firewall.extraForwardRules = ''
    iifname "usb0" accept comment "gadget forward out"
  '';

  # Keep the check intact but scoped: the Zero may only reach the tailnet.
  networking.firewall.interfaces.usb0.allowedUDPPorts = [ 67 ];
}
