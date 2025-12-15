{ pkgs }:

pkgs.appimageTools.wrapType2 {
  pname = "cursor";
  version = "2.2.20";

  src = pkgs.fetchurl {
    url = "https://downloads.cursor.com/production/b3573281c4775bfc6bba466bf6563d3d498d1074/linux/x64/Cursor-2.2.20-x86_64.AppImage";
    # use pkgs.lib.fakeSha256 to avoid downloading the file
    sha256 = "sha256-dY42LaaP7CRbqY2tuulJOENa+QUGSL09m07PvxsZCr0=";
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

    # NOTE: Removed GTK/desktop libs - they can conflict with bundled versions
    # and cause dialog hangs:
    # gtk3, glib, pango, cairo, gdk-pixbuf, atk, at-spi2-atk, at-spi2-core, dbus

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
  # test
}
