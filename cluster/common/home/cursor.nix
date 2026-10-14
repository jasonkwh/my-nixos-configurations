{ pkgs }:

let
  cursorVersion = "3.24.12";
in
pkgs.code-cursor.overrideAttrs (old: {
  version = cursorVersion;
  src = pkgs.appimageTools.extract {
    pname = "cursor";
    version = cursorVersion;
    src = pkgs.fetchurl {
      url = "https://downloads.cursor.com/production/37b865941ccb31e2fc90c685157534efca87f964/linux/x64/Cursor-${cursorVersion}-x86_64.AppImage";
      sha256 = "sha256-JQn7QjetruZsUj744a8c2uH3ytX3AVnhGhfrYBBENjY=";
    };
  };
  sourceRoot = "cursor-${cursorVersion}-extracted/usr/share/cursor";
})
