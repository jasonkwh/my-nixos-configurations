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

  # Hermes normally creates this account, but the agent is disabled here.
  # Syncthing still uses it so synced files retain consistent ownership.
  users.groups.hermes = { };
  users.users.hermes = {
    isSystemUser = true;
    group = "hermes";
    home = "/var/lib/hermes";
    createHome = true;
  };
  systemd.tmpfiles.rules = [
    "d /var/lib/syncthing-hermes 0700 hermes hermes -"
  ];

  # 512MB RAM — zram is the only swap.
  zramSwap.memoryPercent = 100;

  time.timeZone = "Australia/Melbourne";
}
