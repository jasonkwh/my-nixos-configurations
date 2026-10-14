{ pkgs }:

let
  cursorVersion = "3.24.18";
in
pkgs.code-cursor.overrideAttrs (old: {
  version = cursorVersion;
  src = pkgs.appimageTools.extract {
    pname = "cursor";
    version = cursorVersion;
    src = pkgs.fetchurl {
      url = "https://downloads.cursor.com/production/be4c9e5350d77747b42cd467cbd3370a753d464b/linux/x64/Cursor-${cursorVersion}-x86_64.AppImage";
      sha256 = "sha256-BO19PqGQlqKGHzu7pqlmIiVDFqprI7+01TF7T2Vboo4=";
    };
  };
  sourceRoot = "cursor-${cursorVersion}-extracted/usr/share/cursor";
})
