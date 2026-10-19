{ pkgs }:

let
  cursorVersion = "3.25.9";
in
pkgs.code-cursor.overrideAttrs (old: {
  version = cursorVersion;
  src = pkgs.appimageTools.extract {
    pname = "cursor";
    version = cursorVersion;
    src = pkgs.fetchurl {
      url = "https://downloads.cursor.com/production/5d4df965746c5d09740842fc0f1331ba1c15783d/linux/x64/Cursor-${cursorVersion}-x86_64.AppImage";
      sha256 = "sha256-ik73lSFq9UNeXBzsO/HAS2gbnTmsUmVBUpP/kUnQMXk=";
    };
  };
  sourceRoot = "cursor-${cursorVersion}-extracted/usr/share/cursor";
})
