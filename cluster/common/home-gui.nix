{ pkgs, ... }:

{
  # Desktop GUI apps shared by NixOS laptops only.
  home.packages = with pkgs; [
    boxbuddy
    libreoffice-qt
    warp
    zoom-us
    protonup-qt
    brave
    code-cursor
  ];
}
