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

  nativeBuildInputs = [ pkgs.findutils ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    mkdir -p $out/share/applications
    mkdir -p $out/share/icons/hicolor/256x256/apps

    # Create wrapper script that suppresses all terminal output
    cat > $out/bin/cursor <<EOF
#!/bin/sh
export G_MESSAGES_DEBUG=""
export G_DEBUG="fatal-criticals"
export WAYLAND_DEBUG=""
export ELECTRON_ENABLE_LOGGING=0
exec ${wrappedCursor}/bin/cursor "\$@" --disable-logging >/dev/null 2>&1
EOF
    chmod +x $out/bin/cursor

    # Copy icon from extracted AppImage (find the actual location)
    icon=$(find ${appimageContents} -name "cursor.png" -type f | head -n 1)
    if [ -n "$icon" ]; then
      cp "$icon" $out/share/icons/hicolor/256x256/apps/cursor.png
    else
      # Fallback: copy any PNG icon found
      icon=$(find ${appimageContents} -name "*.png" -path "*/icons/*" -type f | head -n 1)
      if [ -n "$icon" ]; then
        cp "$icon" $out/share/icons/hicolor/256x256/apps/cursor.png
      fi
    fi

    # Create desktop file
    cat > $out/share/applications/cursor.desktop <<EOF
[Desktop Entry]
Name=Cursor
Comment=AI-first Code Editor
Exec=$out/bin/cursor %F
Icon=$out/share/icons/hicolor/256x256/apps/cursor.png
Type=Application
Categories=Development;IDE;TextEditor;
MimeType=text/plain;inode/directory;
StartupWMClass=Cursor
Terminal=false
EOF

    runHook postInstall
  '';

  meta = with pkgs.lib; {
    description = "Cursor - The AI-first Code Editor";
    homepage = "https://cursor.com";
    platforms = [ "x86_64-linux" ];
    mainProgram = "cursor";
  };
}
