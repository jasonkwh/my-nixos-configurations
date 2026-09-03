# Pi 4B (bcm2711) downlink to the Zero 2 W (bcm2710a1) USB gadget link.
#
# A Pi USB-A port feeds the Zero's micro-USB OTG port (power + data in one
# cable). The Zero runs g_ether (CDC ECM); this host sees it as usb0 and
# provides network access through its Wi-Fi uplink.
{ lib, ... }:

{
  # g_ether presents this fixed host-side MAC; rename the otherwise
  # unpredictable enx* interface before network configuration starts.
  systemd.network.links."10-zero-gadget" = {
    matchConfig.MACAddress = "02:55:00:00:00:01";
    linkConfig.Name = "usb0";
  };
  networking.networkmanager.unmanaged = [ "interface-name:usb0" ];

  # Host-side NIC + static address matching the Zero's gadget interface.
  networking.interfaces.usb0.ipv4.addresses = [
    {
      address = "10.55.0.1";
      prefixLength = 24;
    }
  ];

  # The Zero reaches the internet and joins Tailscale through the Pi 4.
  networking.nat = {
    enable = true;
    internalInterfaces = [ "usb0" ];
    externalInterface = "wlan0";
  };
  boot.kernel.sysctl."net.ipv4.ip_forward" = lib.mkForce 1;

  networking.firewall.trustedInterfaces = [ "usb0" ];
  networking.firewall.extraForwardRules = ''
    iifname "usb0" accept comment "gadget forward out"
  '';
}
