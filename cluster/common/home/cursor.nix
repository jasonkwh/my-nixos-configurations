{ pkgs }:

let
  cursorVersion = "3.28.7";
in
pkgs.code-cursor.overrideAttrs (old: {
  version = cursorVersion;
  src = pkgs.appimageTools.extract {
    pname = "cursor";
    version = cursorVersion;
    src = pkgs.fetchurl {
      url = "https://downloads.cursor.com/production/25b52e7d03ebf2d5608914158e119f7992432a34/linux/x64/Cursor-${cursorVersion}-x86_64.AppImage";
      sha256 = "sha256-r1T5U/dAvXZ4LdreN2HrFKAiDIde+YL8TVtuAMtXMKQ=";
    };
  };
  sourceRoot = "cursor-${cursorVersion}-extracted/usr/share/cursor";
})
