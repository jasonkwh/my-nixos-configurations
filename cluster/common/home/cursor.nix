{ pkgs }:

let
  cursorVersion = "3.27.14";
in
pkgs.code-cursor.overrideAttrs (old: {
  version = cursorVersion;
  src = pkgs.appimageTools.extract {
    pname = "cursor";
    version = cursorVersion;
    src = pkgs.fetchurl {
      url = "https://downloads.cursor.com/production/69b724ebc67ec522c1b5d287a5025f7a7e81be97/linux/x64/Cursor-${cursorVersion}-x86_64.AppImage";
      sha256 = "sha256-/lF0x7R+LLU5CltoV/8TB4zOEn5RZIYtmoMvzM4SNDU=";
    };
  };
  sourceRoot = "cursor-${cursorVersion}-extracted/usr/share/cursor";
})
