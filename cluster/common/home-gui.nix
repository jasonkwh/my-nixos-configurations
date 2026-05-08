{ pkgs, ... }:

{
  # Desktop GUI apps shared by NixOS laptops only.
  home.packages = with pkgs; [
    boxbuddy
    libreoffice-qt
    packet
    warp
    zoom-us
  ];
}
