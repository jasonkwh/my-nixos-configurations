{ pkgs }:

pkgs.appimageTools.wrapType2 {
  pname = "cursor";
  version = "2.5.25";

  src = pkgs.fetchurl {
    url = "https://downloads.cursor.com/production/7150844152b426ed50d2b68dd6b33b5c5beb73ca/linux/x64/Cursor-2.5.25-x86_64.AppImage";
    # use pkgs.lib.fakeSha256 to avoid downloading the file
    sha256 = "sha256-6ldXKM21FP/ICwowJa6Fi48CR/4MMRNQ0VUv75xOZYE=";
  };

  extraPkgs = pkgs: with pkgs; [
    # Core libraries for Electron/native modules
    libxkbcommon
    xorg.libX11
    xorg.libXrandr
    xorg.libXcursor
    xorg.libXi
    xorg.libXdamage
    xorg.libXcomposite
    xorg.libXfixes
    xorg.libXtst
    xorg.libxcb
    xorg.libxshmfence

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
    gnome-keyring

    # For native modules
    stdenv.cc.cc.lib
  ];
}
