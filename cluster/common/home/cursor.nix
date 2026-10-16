{ pkgs }:

let
  cursorVersion = "3.25.6";
in
pkgs.code-cursor.overrideAttrs (old: {
  version = cursorVersion;
  src = pkgs.appimageTools.extract {
    pname = "cursor";
    version = cursorVersion;
    src = pkgs.fetchurl {
      url = "https://downloads.cursor.com/production/f0df777c412b670d09e3eaf214967d779e67c088/linux/x64/Cursor-${cursorVersion}-x86_64.AppImage";
      sha256 = "sha256-aapO64z5z1J7gxx/1y5Pe0NyaItKXT2q6fsxwjmIgKk=";
    };
  };
  sourceRoot = "cursor-${cursorVersion}-extracted/usr/share/cursor";
})
