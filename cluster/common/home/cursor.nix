{ pkgs }:

let
  cursorVersion = "3.27.12";
in
pkgs.code-cursor.overrideAttrs (old: {
  version = cursorVersion;
  src = pkgs.appimageTools.extract {
    pname = "cursor";
    version = cursorVersion;
    src = pkgs.fetchurl {
      url = "https://downloads.cursor.com/production/df132ffba90dfc15a12e6b8f020ba4e5d026c4be/linux/x64/Cursor-${cursorVersion}-x86_64.AppImage";
      sha256 = "sha256-h8FK0jPzppekHf6tj8xL5APdOjs5g7T7kcnZn9qgy70=";
    };
  };
  sourceRoot = "cursor-${cursorVersion}-extracted/usr/share/cursor";
})
