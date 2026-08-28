{ config, lib, pkgs, system, username, fullName, email, homeDirectory, ... }:

let
  repoBundle = pkgs.runCommand "my-nixos-configurations-bundle" { } ''
    mkdir -p "$out/share"
    cp -R ${../..} "$out/share/my-nixos-configurations"
    chmod -R u+rwX,go+rX "$out/share/my-nixos-configurations"
  '';

  copyRepo = pkgs.writeShellScriptBin "copy-shengos-config" ''
    set -eu
    id "${username}" >/dev/null
    target=${homeDirectory}/Documents/my-nixos-configurations
    mkdir -p "$(dirname "$target")"
    rm -rf "$target"
    cp -R --no-preserve=ownership \
      ${repoBundle}/share/my-nixos-configurations "$target"
    chown -R ${username}:users "$target"
    chmod -R u+rwX,go+rX "$target"
    grep -q experimental-features /mnt/etc/nix/nix.conf 2>/dev/null || \
      echo "experimental-features = nix-command flakes" >> /mnt/etc/nix/nix.conf
  '';

  # Branding substitutions for Calamares' branding.desc.  Each entry matches
  # by leading key (whitespace-tolerant) so upstream formatting drift does not
  # silently skip a replacement; every substitution is asserted afterwards.
  brandingSubstitutions = [
    { key = "componentName"; value = "shengos"; }
    { key = "shortProductName"; value = "ShengOS"; }
    { key = "versionedName"; value = "ShengOS"; }
    { key = "shortVersionedName"; value = "ShengOS"; }
    { key = "bootloaderEntryName"; value = "ShengOS"; }
    { key = "productUrl"; value = "https://github.com/jasonkwh"; }
    { key = "productIcon"; value = "\"shengos.png\""; }
    { key = "productLogo"; value = "\"shengos.png\""; }
    { key = "productWelcome"; value = "\"shengos.png\""; }
  ];

  sedExpr = lib.concatMapStringsSep "\n"
    ({ key, value }: ''
      sed -i -E 's|^[[:space:]]*(${key}):[[:space:]]*.*$|\1: ${value}|' "$out/branding.desc"
      grep -qF '${key}: ${value}' "$out/branding.desc" || {
        echo "branding substitution failed for ${key}" >&2
        exit 1
      }
    '')
    brandingSubstitutions;

  shengosBranding = pkgs.runCommand "shengos-calamares-branding" { } ''
    cp -R ${pkgs.calamares-nixos-extensions}/share/calamares/branding/nixos "$out"
    chmod -R u+w "$out"
    ${sedExpr}
    cp ${../../assets/logos/logo.png} "$out/shengos.png"
  '';

  calamaresUsers =
    let
      result = builtins.replaceStrings
        [ "hostname:\n" ]
        [ "presets:\n    fullName:\n        value: \"${fullName}\"\n        editable: true\n    loginName:\n        value: \"${username}\"\n        editable: true\n\nhostname:\n" ]
        (builtins.readFile "${pkgs.calamares-nixos-extensions}/etc/calamares/modules/users.conf");
    in
    assert lib.hasInfix "loginName:" result
      && lib.hasInfix "presets:" result;
    result;

  liveWallpaper = pkgs.runCommand "shengos-live-wallpaper" { } ''
    mkdir -p "$out/share/backgrounds/shengos"
    cp ${../../assets/wallpapers/DSCF4098.JPG} \
      "$out/share/backgrounds/shengos/DSCF4098.JPG"
  '';

  calamaresSettings =
    let
      result = builtins.replaceStrings
        [ "- module:   nixos\n  weight:   48\n" "  - nixos\n  - users\n  - umount\n" "branding: nixos" ]
        [ "- module:   nixos\n  weight:   48\n- id:       copy-shengos-config\n  module:   shellprocess\n  config:   copy-shengos-config.conf\n"
          "  - nixos\n  - users\n  - copy-shengos-config\n  - umount\n"
          "branding: shengos" ]
        (builtins.readFile "${pkgs.calamares-nixos-extensions}/etc/calamares/settings.conf");
    in
    assert lib.hasInfix "copy-shengos-config.conf" result
      && lib.hasInfix "branding: shengos" result
      && ! lib.hasInfix "branding: nixos" result;
    result;
in
{
  imports = [
  ];

  home-manager.users.${username} = {
    home = {
      inherit username homeDirectory;
      stateVersion = "24.11";
    };

    programs.git = {
      enable = true;
      settings.user = {
        name = fullName;
        email = email;
      };
    };

    programs.plasma = {
      enable = true;
      workspace = {
        wallpaper = "${liveWallpaper}/share/backgrounds/shengos/DSCF4098.JPG";
        lookAndFeel = "org.kde.breezedark.desktop";
        colorScheme = "BreezeDark";
      };
    };
  };

  system.nixos = {
    distroName = "ShengOS";
    extraOSReleaseArgs = {
      LOGO = "shengos";
      HOME_URL = "https://github.com/jasonkwh";
    };
  };

  users.users.${username} = {
    isNormalUser = true;
    description = fullName;
    home = homeDirectory;
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.bashInteractive;
    # Upstream installer module hard-codes autoLogin.user = "nixos";
    # override for the ShengOS live user and allow passwordless login.
    initialPassword = "";
  };

  services.displayManager.autoLogin = {
    enable = lib.mkForce true;
    user = lib.mkForce username;
  };

  nixpkgs.config.allowUnfree = true;
  # broadcom_sta (BCM4360 Wi-Fi, Mac Pro 2013) is EOL upstream; the only
  # driver for this chip. Known-risky, accepted deliberately.
  nixpkgs.config.permittedInsecurePackages = [ "broadcom-sta-6.30.223.271-59-6.18.46" ];
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  networking.networkmanager.enable = true;
  i18n.defaultLocale = "en_AU.UTF-8";

  # The Calamares shellprocess runs this after nixos-install and before the
  # target filesystem is unmounted.  The repository is therefore guaranteed
  # to be present in the installed user's Documents directory.
  environment.systemPackages = with pkgs; [
    copyRepo
    btrfs-progs
    curl
    efibootmgr
    git
    hw-probe
    kdePackages.partitionmanager
    nvme-cli
    pciutils
    rsync
    smartmontools
    usbutils
    vim
    wget
    liveWallpaper
  ];

  # CJK fonts so Chinese, Japanese and Korean render correctly in the Live
  # environment (file managers, terminals, LibreOffice preview) and in the
  # freshly installed Calamares target.  Mirrors the font set in
  # common/configuration.nix.
  fonts = {
    fontDir.enable = true;
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      source-han-mono
      nerd-fonts.noto
      nerd-fonts.jetbrains-mono
    ];

    fontconfig = {
      enable = true;
      antialias = true;
      hinting = {
        enable = true;
      };
    };
  };
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

  # Include proprietary firmware so the portable image works across more
  # laptops and desktops (Wi-Fi, Bluetooth, and other device firmware).
  hardware.enableAllFirmware = true;

  # A Live image must be hardware-neutral and must not resume or configure
  # the installed laptops' swap devices.
  boot.resumeDevice = lib.mkForce "";

  # Live environment imports no ZFS pools; silence upstream evaluation
  # warning (cluster/common fix does not reach this config).
  boot.zfs.forceImportRoot = false;
  swapDevices = lib.mkForce [ ];
  hardware.cpu.amd.updateMicrocode = lib.mkForce false;
  hardware.cpu.intel.updateMicrocode = lib.mkForce false;

  # Mac Pro 2013 (trashcan) support, verified by community reports:
  # - FirePro D-series (GCN1) works via modern amdgpu with DC;
  # - intel_iommu=off fixes random crashes (Debian wiki / MacPro6,1).
  boot.kernelParams = [ "radeon.si_support=0" "amdgpu.si_support=1" "amdgpu.dc=1" "intel_iommu=off" ];
  boot.extraModulePackages = [
    # BCM4360 (14e4:43a0) Wi-Fi: only the out-of-tree broadcom-wl driver.
    # Best-effort: if the module fails to build against linux_latest this
    # config fails to eval — fall back to Ethernet-only then.
    config.boot.kernelPackages.broadcom_sta
  ];

  # The installer image should discover graphics hardware rather than force
  # the AMD-only or Intel-only laptop driver settings.
  services.xserver.videoDrivers = lib.mkForce [ "amdgpu" "radeon" "modesetting" ];
  services.desktopManager.plasma6.enableQt5Integration = lib.mkForce true;

  # Do not install a bootloader to the USB user's firmware variables.
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  # Keep the image identifiable as a Live USB rather than as either laptop.
  image.fileName = lib.mkForce "shengos-live-${config.system.nixos.release}-${system}.iso";
  isoImage.volumeID = "SHENGOS_LIVE";
  image.baseName = lib.mkForce "shengos-live-${config.system.nixos.release}-${system}";

  # A portable troubleshooting/install USB should not prompt for a sudo
  # password.  The normal installed systems keep their existing policy.
  security.sudo.wheelNeedsPassword = false;
}
