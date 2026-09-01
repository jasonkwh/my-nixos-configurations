# Raspberry Pi Zero 2 W (BCM2710A1, aarch64) — headless MQTT thin client.
{ username, ... }:

{
  imports = [
    ../common/configuration.nix
    ./usb-gadget.nix
  ];

  home-manager.users.${username} = {
    imports = [
      ../common/home.nix
      ./home.nix
    ];
  };

  # 512MB RAM — zram is the only swap.
  zramSwap.memoryPercent = 100;

  time.timeZone = "Australia/Melbourne";
}
