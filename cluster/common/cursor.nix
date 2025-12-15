{ pkgs }:

let
  pname = "cursor";
  version = "2.2.20";

  src = pkgs.fetchurl {
    url = "https://downloads.cursor.com/production/b3573281c4775bfc6bba466bf6563d3d498d1074/linux/x64/Cursor-2.2.20-x86_64.AppImage";
    # use pkgs.lib.fakeSha256 to avoid downloading the file
    sha256 = "sha256-dY42LaaP7CRbqY2tuulJOENa+QUGSL09m07PvxsZCr0=";
  };

  appimageContents = pkgs.appimageTools.extractType2 { inherit pname version src; };

  wrappedCursor = pkgs.appimageTools.wrapType2 {
    inherit pname version src;

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

      # GTK/desktop integration
      gtk3
      glib
      pango
      cairo
      gdk-pixbuf
      atk
      at-spi2-atk
      at-spi2-core
      dbus

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
pkgs.stdenv.mkDerivation {
  inherit pname version;

  src = wrappedCursor;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    mkdir -p $out/share/applications
    mkdir -p $out/share/icons/hicolor/512x512/apps

    # Create wrapper with flags to suppress errors and warnings
    makeWrapper ${wrappedCursor}/bin/cursor $out/bin/cursor \
      --add-flags "--disable-gpu-vsync" \
      --add-flags "--enable-features=UseOzonePlatform" \
      --add-flags "--ozone-platform-hint=auto" \
      --set G_MESSAGES_DEBUG "" \
      --set G_DEBUG "fatal-criticals"

    # Copy desktop file and icon
    cp ${appimageContents}/cursor.desktop $out/share/applications/cursor.desktop
    cp ${appimageContents}/cursor.png $out/share/icons/hicolor/512x512/apps/cursor.png

    # Fix desktop file paths
    substituteInPlace $out/share/applications/cursor.desktop \
      --replace-fail "Exec=cursor" "Exec=$out/bin/cursor" \
      --replace-fail "Icon=cursor" "Icon=$out/share/icons/hicolor/512x512/apps/cursor.png"

    runHook postInstall
  '';

  meta = with pkgs.lib; {
    description = "Cursor - The AI-first Code Editor";
    homepage = "https://cursor.com";
    platforms = [ "x86_64-linux" ];
    mainProgram = "cursor";
  };
}
