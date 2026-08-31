# Imported only when a host sets isHeadless = true in flake.nix.
# Strips desktop/GUI/heavy bits so small boards (e.g. RPi 4B)
# spend their RAM and CPU on headless services instead of Plasma.
{ lib, ... }:

{
  # Desktop stack off.
  services.displayManager.sddm.enable = lib.mkForce false;
  services.desktopManager.plasma6.enable = lib.mkForce false;
  services.xserver.enable = lib.mkForce false;
  services.packagekit.enable = lib.mkForce false;
  services.flatpak.enable = lib.mkForce false;

  # No desktop, no input method, no printing by default on the board.
  i18n.inputMethod.enable = lib.mkForce false;
  services.printing.enable = lib.mkForce false;

  # fwupd-efi cross-build broken on aarch64
  services.fwupd.enable = lib.mkForce false;

  # GUI programs and gaming stack off (steam, gamemode).
  programs.steam.enable = lib.mkForce false;
  programs.gamemode.enable = lib.mkForce false;

  # Graphics off entirely: enable=false alone doesn't stop mesa being pulled
  # in via extraPackages/enable32Bit, which forces the huge cross-LLVM+mesa
  # build into the SD-image closure.
  hardware.graphics = lib.mkForce {
    enable = false;
    enable32Bit = false;
    extraPackages = [ ];
    extraPackages32 = [ ];
  };

  # No container runtime on small boards.
  virtualisation.podman.enable = lib.mkForce false;
}
