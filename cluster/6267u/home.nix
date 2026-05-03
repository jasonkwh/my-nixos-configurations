{ config, pkgs, nixgl, ... }:

{
  # Configure nixGL wrappers for non-NixOS GPU acceleration.
  targets.genericLinux.nixGL = {
    packages = nixgl.packages;
    defaultWrapper = "mesa";
    installScripts = [ "mesa" ];
  };

  programs.zsh.shellAliases = {
    brave = "nixGLMesa brave";
    code = "nixGLMesa code";
  };

  # Add user-specific packages here.
  # home.packages = with pkgs; [
  #   
  # ];

  # Add machine-specific home-manager settings here.
}
