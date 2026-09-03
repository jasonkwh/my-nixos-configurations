# Raspberry Pi Zero 2 W (BCM2710A1, aarch64) — headless MQTT thin client.
{ lib, username, ... }:

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

  # Keep this 512MB edge node lean; Syncthing remains enabled so it can
  # provide another backup replica for the fleet.
  services.hermes-agent.enable = lib.mkForce false;

  # 512MB RAM — zram is the only swap.
  zramSwap.memoryPercent = 100;

  time.timeZone = "Australia/Melbourne";
}
