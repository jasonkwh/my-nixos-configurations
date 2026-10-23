{ pkgs }:

let
  cursorVersion = "3.27.6";
in
pkgs.code-cursor.overrideAttrs (old: {
  version = cursorVersion;
  src = pkgs.appimageTools.extract {
    pname = "cursor";
    version = cursorVersion;
    src = pkgs.fetchurl {
      url = "https://downloads.cursor.com/production/f7119520544accb8dcf6d27119b9f1963d8ee5ae/linux/x64/Cursor-${cursorVersion}-x86_64.AppImage";
      sha256 = "sha256-rifOXrVh0k1JV+C7/n9qR8Op2/jENsAKV7gleaD30t0=";
    };
  };
  sourceRoot = "cursor-${cursorVersion}-extracted/usr/share/cursor";
})
