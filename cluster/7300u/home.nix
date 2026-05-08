{ config, pkgs, ... }:

{
  # Add user-specific packages here.
  home.packages = with pkgs; [
    thunderbird
  ];

  # Add machine-specific home-manager settings here.
}
