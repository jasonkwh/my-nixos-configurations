{ pkgs }:

let
  cursorVersion = "3.26.13";
in
pkgs.code-cursor.overrideAttrs (old: {
  version = cursorVersion;
  src = pkgs.appimageTools.extract {
    pname = "cursor";
    version = cursorVersion;
    src = pkgs.fetchurl {
      url = "https://downloads.cursor.com/production/3bfec373749d3d4a53a151283022d49743ab50ba/linux/x64/Cursor-${cursorVersion}-x86_64.AppImage";
      sha256 = "sha256-AASLI1+7WXIXZmz2oQZO+qaNC93k3rIgvCmIj6gL/a0=";
    };
  };
  sourceRoot = "cursor-${cursorVersion}-extracted/usr/share/cursor";
})
