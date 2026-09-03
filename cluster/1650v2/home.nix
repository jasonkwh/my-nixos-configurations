# Per-host extras for the trashcan (gaming/emulation + fleet node).
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    retroarch-full
    steam
    mangohud
  ];
}
