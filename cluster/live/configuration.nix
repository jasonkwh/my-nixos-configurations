{ config, lib, pkgs, username, ... }:

let
  repoBundle = pkgs.runCommand "my-nixos-configurations-bundle" { } ''
    mkdir -p "$out/share"
    cp -R ${../..} "$out/share/my-nixos-configurations"
    chmod -R u+rwX,go+rX "$out/share/my-nixos-configurations"
  '';

  copyRepo = pkgs.writeShellScriptBin "copy-shengos-config" ''
    set -eu
    target=/home/jasonkwh/Documents/my-nixos-configurations
    mkdir -p "$(dirname "$target")"
    rm -rf "$target"
    cp -R --no-preserve=ownership \
      ${repoBundle}/share/my-nixos-configurations "$target"
    chown -R jasonkwh:users "$target"
    chmod -R u+rwX,go+rX "$target"
  '';

  shengosBranding = pkgs.runCommand "shengos-calamares-branding" { } ''
    cp -R ${pkgs.calamares-nixos-extensions}/share/calamares/branding/nixos "$out"
    substituteInPlace "$out/branding.desc" \
      --replace-fail 'componentName:  nixos' 'componentName:  shengos' \
      --replace-fail 'shortProductName:    NixOS' 'shortProductName:    ShengOS' \
      --replace-fail 'versionedName:       NixOS' 'versionedName:       ShengOS' \
      --replace-fail 'shortVersionedName:  NixOS' 'shortVersionedName:  ShengOS' \
      --replace-fail 'bootloaderEntryName: NixOS' 'bootloaderEntryName: ShengOS' \
      --replace-fail 'productUrl:          https://nixos.org/' 'productUrl:          https://github.com/jasonkwh' \
      --replace-fail 'productIcon:         "nix-snowflake.svg"' 'productIcon:         "shengos.png"' \
      --replace-fail 'productLogo:         "white.png"' 'productLogo:         "shengos.png"' \
      --replace-fail 'productWelcome:      "nix-snowflake.svg"' 'productWelcome:      "shengos.png"'
    cp ${../../assets/logos/logo.png} "$out/shengos.png"
  '';

  calamaresUsers = builtins.replaceStrings
    [ "hostname:\n" ]
    [ "presets:\n    fullName:\n        value: \"Jason Huang\"\n        editable: true\n    loginName:\n        value: \"jasonkwh\"\n        editable: true\n\nhostname:\n" ]
    (builtins.readFile "${pkgs.calamares-nixos-extensions}/etc/calamares/modules/users.conf");

  calamaresSettings = builtins.replaceStrings
    [ "- module: nixos\n  weight:   48\n" "  - nixos\n  - users\n  - umount\n" "branding: nixos" ]
    [ "- module: nixos\n  weight:   48\n- id:       copy-shengos-config\n  module:   shellprocess\n  config:   copy-shengos-config.conf\n"
      "  - nixos\n  - users\n  - copy-shengos-config\n  - umount\n"
      "branding: shengos" ]
    (builtins.readFile "${pkgs.calamares-nixos-extensions}/etc/calamares/settings.conf");
in
{
  imports = [
    ../common/configuration.nix
  ];

  # Reuse the shared Home Manager environment, but do not apply either
  # laptop's hardware-specific home configuration.
  home-manager.users.${username} = {
    imports = [
      ../common/home.nix
      ../common/home-gui.nix
    ];
  };

  # The Calamares shellprocess runs this after nixos-install and before the
  # target filesystem is unmounted.  The repository is therefore guaranteed
  # to be present in the installed user's Documents directory.
  environment.systemPackages = [ copyRepo ];
  environment.etc."calamares/settings.conf".text = calamaresSettings;
  environment.etc."calamares/modules/users.conf".text = calamaresUsers;
  environment.etc."calamares/branding/shengos".source = shengosBranding;
  environment.etc."calamares/modules/copy-shengos-config.conf".text = ''
    dontChroot: false
    script:
      - command: ${copyRepo}/bin/copy-shengos-config
        timeout: 120
  '';

  networking.hostName = "jasonkwh-live";
  time.timeZone = "Australia/Melbourne";

  # A Live image must be hardware-neutral and must not resume or configure
  # the installed laptops' swap devices.
  boot.resumeDevice = lib.mkForce "";
  swapDevices = lib.mkForce [ ];
  hardware.cpu.amd.updateMicrocode = lib.mkForce false;
  hardware.cpu.intel.updateMicrocode = lib.mkForce false;

  # The installer image should discover graphics hardware rather than force
  # the AMD-only or Intel-only laptop driver settings.
  services.xserver.videoDrivers = lib.mkForce [ "modesetting" ];
  services.desktopManager.plasma6.enableQt5Integration = lib.mkForce true;

  # These services depend on persistent host secrets/state and are deliberately
  # omitted from a portable USB session.
  services.hermes-agent.enable = lib.mkForce false;
  services.resilio.enable = lib.mkForce false;
  services.github-runners.jasonkwh-live.enable = lib.mkForce false;
  services.openssh.enable = lib.mkForce false;
  services.tailscale.enable = lib.mkForce false;
  services.fstrim.enable = lib.mkForce false;
  services.irqbalance.enable = lib.mkForce false;
  services.fwupd.enable = lib.mkForce false;
  services.packagekit.enable = lib.mkForce false;

  # Do not install a bootloader to the USB user's firmware variables.
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  # Keep the image identifiable as a Live USB rather than as either laptop.
  image.fileName = "shengos-live-${config.system.nixos.release}-x86_64.iso";

  # A portable troubleshooting/install USB should not prompt for a sudo
  # password.  The normal installed systems keep their existing policy.
  security.sudo.wheelNeedsPassword = false;
}
