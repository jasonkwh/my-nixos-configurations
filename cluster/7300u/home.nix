{ config, pkgs, ... }:

{
  # Add user-specific packages here.
  # home.packages = with pkgs; [
  #   
  # ];

  # Disable KDE Tablet Mode (using plasma-manager to avoid overwriting other settings)
  programs.plasma = {
    enable = true;
    configFile."kdeglobals"."KDE"."TabletMode" = "Never";
  };
}
