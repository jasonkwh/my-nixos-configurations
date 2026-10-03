{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    audacious
  ];
}
