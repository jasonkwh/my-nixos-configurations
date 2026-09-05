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

  # The nixos-hardware Pi 4 module replaces the generic SD-image firmware
  # population step, so explicitly include U-Boot and point config.txt at it.
  hardware.raspberry-pi.firmware.uboot.enable = true;

  zramSwap.memoryPercent = 50;

  # 4GB Pi + WhatsApp gateway: cap concurrent kanban workers (fleet default is unset/unlimited).
  services.hermes-agent.settings.kanban.max_in_progress = 3;

  time.timeZone = "Australia/Melbourne";
}
