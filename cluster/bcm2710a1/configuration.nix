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

  # Avoid running several derivations and compiler workers concurrently on
  # 512MB. The default "auto" setting starts four jobs, which pushes this
  # board into sustained zram/SD-card thrashing and is slower in practice.
  nix.settings = {
    max-jobs = lib.mkForce 1;
    cores = lib.mkForce 2;
    # Per-path optimisation adds extra reads and writes to every store import.
    # Deduplication is less valuable than write latency on this small SD node.
    auto-optimise-store = lib.mkForce false;
  };

  time.timeZone = "Australia/Melbourne";
}
