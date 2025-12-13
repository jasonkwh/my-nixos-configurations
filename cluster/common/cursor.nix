{ pkgs }:

pkgs.appimageTools.wrapType2 {
  pname = "cursor";
  version = "2.2.20";

  src = pkgs.fetchurl {
    url = "https://downloads.cursor.com/production/b3573281c4775bfc6bba466bf6563d3d498d1074/linux/x64/Cursor-2.2.20-x86_64.AppImage";
    # use pkgs.lib.fakeSha256 to avoid downloading the file
    sha256 = "sha256-dY42LaaP7CRbqY2tuulJOENa+QUGSL09m07PvxsZCr0=";
  };

  extraPkgs = pkgs: with pkgs; [ ];
}
