{ pkgs }:

let
  cursorVersion = "3.26.16";
in
pkgs.code-cursor.overrideAttrs (old: {
  version = cursorVersion;
  src = pkgs.appimageTools.extract {
    pname = "cursor";
    version = cursorVersion;
    src = pkgs.fetchurl {
      url = "https://downloads.cursor.com/production/8fcb8ace5c73fa31f2e2707fd6783160e4ed3e49/linux/x64/Cursor-${cursorVersion}-x86_64.AppImage";
      sha256 = "sha256-2eaL9MIFGeNL8ZTwQ+SAVzDFv9eIImuiMMF/QFCGxAE=";
    };
  };
  sourceRoot = "cursor-${cursorVersion}-extracted/usr/share/cursor";
})
