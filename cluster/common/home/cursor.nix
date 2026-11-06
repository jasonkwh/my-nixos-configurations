{ pkgs }:

let
  cursorVersion = "3.29.9";
in
pkgs.code-cursor.overrideAttrs (old: {
  version = cursorVersion;
  src = pkgs.appimageTools.extract {
    pname = "cursor";
    version = cursorVersion;
    src = pkgs.fetchurl {
      url = "https://downloads.cursor.com/production/306d153d51d714882ab7b1bc49649cab624e8a31/linux/x64/Cursor-${cursorVersion}-x86_64.AppImage";
      sha256 = "sha256-xDtVthf031Xgmgv9fj54IJxuwQuCFcgupePxn11MppM=";
    };
  };
  sourceRoot = "cursor-${cursorVersion}-extracted/usr/share/cursor";
})
