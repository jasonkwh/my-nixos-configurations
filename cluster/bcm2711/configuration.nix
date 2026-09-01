# Raspberry Pi 4B (BCM2711, aarch64) — headless Hermes node.
{ username, ... }:

{
  imports = [
    ../common/configuration.nix
    ./gadget-downlink.nix
  ];

  home-manager.users.${username} = {
    imports = [
      ../common/home.nix
      ./home.nix
    ];
  };

  zramSwap.memoryPercent = 50;

  time.timeZone = "Australia/Melbourne";
}
