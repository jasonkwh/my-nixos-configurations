{ pkgs }:

let
  base = pkgs.appimageTools.wrapType2 {
    pname = "cursor";
    version = "3.6.21";

    src = pkgs.fetchurl {
      url = "https://downloads.cursor.com/production/e7a7e93f4d75f8272503ecf33cedbaae10114a15/linux/x64/Cursor-3.6.21-x86_64.AppImage";
      # use pkgs.lib.fakeSha256 to avoid downloading the file
      sha256 = "sha256-xizk2rlN9MA7CLEWouKzQqNmzklU/7I1nVnIAjHXDOg=";
    };

    extraPkgs = pkgs: with pkgs; [
      # Core libraries for Electron/native modules
      libxkbcommon
      libx11
      libxrandr
      libxcursor
      libxi
      libxdamage
      libxcomposite
      libxfixes
      libxtst
      libxcb
      libxshmfence

      # Audio/video
      alsa-lib
      pipewire
      pulseaudio
      libpulseaudio

      # Graphics
      mesa
      libGL
      libdrm
      vulkan-loader

      # Other dependencies
      nss
      nspr
      cups
      expat
      libxkbfile
      systemd
      libsecret

      # For native modules
      stdenv.cc.cc.lib
    ];
  };
in
  # Keep Cursor close to the upstream AppImage launch path. Forcing Chromium GPU
  # flags here has caused Electron utility processes to SIGTRAP on this AMD
  # Wayland setup.
  base
