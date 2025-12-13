{ config, pkgs, ... }:

{
  # Add user-specific packages here.
  # home.packages = with pkgs; [
  #   
  # ];

  # Disable KDE Tablet Mode
  home.file.".config/kdeglobals".text = ''
    [KDE]
    TabletMode=Never
  '';
}
