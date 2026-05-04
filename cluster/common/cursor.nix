{ pkgs }:

let
  base = pkgs.appimageTools.wrapType2 {
    pname = "cursor";
    version = "3.1.17";

    src = pkgs.fetchurl {
      url = "https://downloads.cursor.com/production/fce1e9ab7844f9ea35793da01e634aa7e50bce90/linux/x64/Cursor-3.1.17-x86_64.AppImage";
      # use pkgs.lib.fakeSha256 to avoid downloading the file
      sha256 = "sha256-+Pk5MvQSjhoKJdtN+pWX/vcyWnHmbXvJ5wFDvgtHo20=";
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
  };
in
  # Wrap the binary to inject rendering flags at launch.
  # --ozone-platform-hint=auto: use native Wayland when available, avoids
  # XWayland translation overhead (zygote was observed at ~40% CPU without).
  # --disable-features=RendererCodeIntegrity: reduces per-window sandbox cost.
  # --use-gl=desktop/--enable-gpu-rasterization/--enable-zero-copy:
  # conservative rendering hints that generally improve smoothness without
  # forcing unsupported GPU paths.
  pkgs.symlinkJoin {
    name = "cursor-3.1.17";
    paths = [ base ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/cursor \
        --add-flags "--use-gl=desktop" \
        --add-flags "--enable-gpu-rasterization" \
        --add-flags "--enable-zero-copy" \
        --add-flags "--ozone-platform-hint=auto" \
        --add-flags "--disable-features=RendererCodeIntegrity"
    '';
  }
