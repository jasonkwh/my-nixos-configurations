{ pkgs, ... }:

let
  cursor = import ./cursor.nix { inherit pkgs; };
in
{
  # Desktop GUI apps shared by NixOS laptops only.
  home.packages = with pkgs; [
    boxbuddy
    libreoffice-qt
    warp
    zoom-us
    protonup-qt
    brave
    cursor
  ];
}
