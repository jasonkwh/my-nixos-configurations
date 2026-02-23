{ pkgs }:

pkgs.appimageTools.wrapType2 {
  pname = "cursor";
  version = "2.5.20";

  src = pkgs.fetchurl {
    url = "https://downloads.cursor.com/production/511523af765daeb1fa69500ab0df5b6524424612/linux/x64/Cursor-2.5.20-x86_64.AppImage";
    # use pkgs.lib.fakeSha256 to avoid downloading the file
    sha256 = "sha256-csvj0THOX/RPi7Docv033mi8DlEOEdnjFIQ8jL7HPO8=";
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
