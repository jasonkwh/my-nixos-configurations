{ pkgs, ... }:

{
  # Desktop GUI apps shared by NixOS laptops only.
  home.packages = with pkgs; [
    boxbuddy
    libreoffice-qt
    kdePackages.isoimagewriter
    vscode
    beekeeper-studio
    postman
    mongodb-compass
    neo4j-desktop
    packet
    warp
  ];
}
