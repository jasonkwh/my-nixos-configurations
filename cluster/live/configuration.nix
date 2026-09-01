{ config, lib, pkgs, system, username, fullName, email, homeDirectory, ... }:

let
  repoBundle = pkgs.runCommand "my-nixos-configurations-bundle" { } ''
    mkdir -p "$out/share"
    cp -R ${../..} "$out/share/my-nixos-configurations"
    chmod -R u+rwX,go+rX "$out/share/my-nixos-configurations"
  '';

  copyRepo = pkgs.writeShellScriptBin "copy-shengos-config" ''
    set -eu
    target=/mnt${homeDirectory}/Documents/my-nixos-configurations
    mkdir -p "$(dirname "$target")"
    rm -rf "$target"
    cp -R --no-preserve=ownership \
      ${repoBundle}/share/my-nixos-configurations "$target"
    chmod -R u+rwX,go+rX "$target"
    grep -q experimental-features /mnt/etc/nix/nix.conf 2>/dev/null || \
      echo "experimental-features = nix-command flakes" >> /mnt/etc/nix/nix.conf
  '';

  # Password-gated secrets install AND login-password provisioning: the ISO
  # contains ONLY ciphertext (shengos-secrets.tar.enc, sealed with `make live`
  # using the machine's password — the same one used for sudo).  Calamares'
  # user page does NOT set the password; instead this script asks for it via
  # kdialog (the only prompt), decrypts the seal, and on success sets the
  # target user's login password (and root's) to match.  A wrong password
  # means no decrypt AND no password — installation aborts.  When no sealed
  # file was baked in, no password is prompted and secrets must be copied
  # over Tailscale afterwards (docs/install.md).
  installSecrets = pkgs.writeShellScriptBin "install-shengos-secrets" ''
    set -eu
    encfile=""
    for f in /run/media/system-iso/shengos-secrets.tar.enc \
             /iso/shengos-secrets.tar.enc \
             /run/media/*/*/shengos-secrets.tar.enc /media/*/*/shengos-secrets.tar.enc; do
      if [ -f "$f" ]; then encfile="$f"; break; fi
    done
    target=/mnt${homeDirectory}/.secrets
    if [ -z "$encfile" ]; then
      echo "install-shengos-secrets: no shengos-secrets.tar.enc on install medium; skipping"
      exit 0
    fi
    mkdir -p "$target"
    tries=0
    while [ "$tries" -lt 3 ]; do
      tries=$((tries + 1))
      pass=$(${pkgs.kdePackages.kdialog}/bin/kdialog --password "Set the login password for user '${username}' (also unlocks shengos-secrets)" --title "ShengOS password") || continue
      [ -n "$pass" ] || continue
      # The password must open the seal; on success it becomes the login
      # password for the target user and root.
      if printf '%s' "$pass" | ${pkgs.openssl}/bin/openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -in "$encfile" -out "$target/.secrets.tar" 2>/dev/null; then
        tar -xf "$target/.secrets.tar" -C "$target" && rm -f "$target/.secrets.tar"
        chmod 700 "$target"
        chmod 600 "$target"/.secrets/* 2>/dev/null || true
        # Provision login passwords: the decrypted-in password becomes both
        # the user's and root's login password (chpasswd generates a proper
        # yescrypt hash into /mnt/etc/shadow).
        printf '%s:%s\n' "${username}" "$pass" | ${pkgs.shadow}/bin/chpasswd --root /mnt -c YESCRYPT
        printf 'root:%s\n' "$pass" | ${pkgs.shadow}/bin/chpasswd --root /mnt -c YESCRYPT
        ${pkgs.kdePackages.kdialog}/bin/kdialog --msgbox "Password set and shengos-secrets installed to ${homeDirectory}/.secrets" --title "ShengOS password"
        exit 0
      fi
      ${pkgs.kdePackages.kdialog}/bin/kdialog --error "Wrong password: shengos-secrets.tar.enc did not decrypt (attempt $tries/3)" --title "ShengOS password"
    done
    ${pkgs.kdePackages.kdialog}/bin/kdialog --sorry "Installation aborted: secrets not unlocked after 3 attempts. Reboot and retry with the correct password." --title "ShengOS password"
    exit 1
  '';

  # The sealed secrets ciphertext baked INTO the ISO at build time.
  # `make live` sets SECRETS_ENC to the sealed file; eval-time only, and
  # inert when unset (ISO then contains no secrets material at all).
  sealedSecrets =
    let src = builtins.getEnv "SECRETS_ENC";
    in lib.optionalString (src != "") src;

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
      # Single-user system: loginName/fullName/hostname are locked presets.
      # The password is NOT set on this page — install-shengos-secrets
      # provisions it from the seal unlock — so the password fields are
      # hidden and root password prompting is disabled.
      result = builtins.replaceStrings
        [ "hostname:\n" "setRootPassword: true" ]
        [ "presets:\n    fullName:\n        value: \"${fullName}\"\n        editable: false\n    loginName:\n        value: \"${username}\"\n        editable: false\n    hostname:\n        value: \"${username}\"\n        editable: false\n    userPassword:\n        value: \"placeholder\"\n        editable: false\n\nhostname:\n" "setRootPassword: false" ]
        (builtins.readFile "${pkgs.calamares-nixos-extensions}/etc/calamares/modules/users.conf");
    in
    assert lib.hasInfix "loginName:" result
      && lib.hasInfix "presets:" result
      && lib.hasInfix "editable: false" result
      && lib.hasInfix "setRootPassword: false" result;
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
        [ "- module:   nixos\n  weight:   48\n- id:       copy-shengos-config\n  module:   shellprocess\n  config:   copy-shengos-config.conf\n- id:       install-shengos-secrets\n  module:   shellprocess\n  config:   install-shengos-secrets.conf\n"
          "  - nixos\n  - users\n  - copy-shengos-config\n  - install-shengos-secrets\n  - umount\n"
          "branding: shengos" ]
        (builtins.readFile "${pkgs.calamares-nixos-extensions}/etc/calamares/settings.conf");
    in
    assert lib.hasInfix "copy-shengos-config.conf" result
      && lib.hasInfix "install-shengos-secrets.conf" result
      && lib.hasInfix "branding: shengos" result
      && ! lib.hasInfix "branding: nixos" result;
    result;
in
{
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
  # driver for this chip. Known-risky, accepted deliberately. Predicate
  # matches by pname so kernel bumps don't break eval.
  nixpkgs.config.allowInsecurePredicate = pkg: lib.getName pkg == "broadcom-sta";
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  networking.networkmanager.enable = true;
  i18n.defaultLocale = "en_AU.UTF-8";

  # The Calamares shellprocess runs this after nixos-install and before the
  # target filesystem is unmounted.  The repository is therefore guaranteed
  # to be present in the installed user's Documents directory.
  # Upstream graphical-base puts firefox in defaultPackages; ISO doesn't need it.
  environment.defaultPackages = lib.mkForce (with pkgs; [ gparted vim nano mesa-demos ]);
  environment.systemPackages = with pkgs; [
    copyRepo
    installSecrets
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
  environment.etc."calamares/modules/install-shengos-secrets.conf".text = ''
    dontChroot: false
    script:
      - command: ${installSecrets}/bin/install-shengos-secrets
        timeout: 60
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

  # Mac Pro 2013 (trashcan) support, per the Debian wiki page for MacPro6,1:
  # - FirePro D-series (GCN1) via modern amdgpu with DC, dpm off (stability);
  # - intel_iommu=off fixes random crashes;
  # - mbpfan: Apple SMC fan curve, needed to keep the twin fans cooling.
  #   https://wiki.debian.org/InstallingDebianOn/Apple/MacPro/6-1
  boot.kernelParams = [ "radeon.si_support=0" "amdgpu.si_support=1" "amdgpu.dc=1" "amdgpu.dpm=0" "intel_iommu=off" ];
  services.mbpfan = {
    enable = true;
    settings.general = {
      min_fan1_speed = 900;
      max_fan1_speed = 6200;
      low_temp = 50;
      high_temp = 55;
      max_temp = 65;
      polling_interval = 1;
    };
  };
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

  # Live USB image identity + optional sealed secrets ciphertext baked into
  # the ISO (unlocking needs the target user's login password — see
  # install-shengos-secrets above).
  image = lib.mkForce {
    fileName = "shengos-live-${config.system.nixos.release}-${system}.iso";
    baseName = "shengos-live-${config.system.nixos.release}-${system}";
  };
  isoImage = {
    volumeID = "SHENGOS_LIVE";
    contents = lib.optionals (sealedSecrets != "") [
      {
        source = sealedSecrets;
        target = "/shengos-secrets.tar.enc";
      }
    ];
  };

  # A portable troubleshooting/install USB should not prompt for a sudo
  # password.  The normal installed systems keep their existing policy.
  security.sudo.wheelNeedsPassword = false;
}
