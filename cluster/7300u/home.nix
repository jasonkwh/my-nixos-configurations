{ config, pkgs, ... }:

{
  # Laptop-shared home configuration (power management profiles, etc.) lives
  # in ../common/home-laptop.nix.

  home.packages = with pkgs; [
    thunderbird
  ];
}
