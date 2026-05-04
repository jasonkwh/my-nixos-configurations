{ config, pkgs, nixgl, ... }:

{
  # Configure nixGL wrappers for non-NixOS GPU acceleration.
  targets.genericLinux.nixGL = {
    packages = nixgl.packages;
    defaultWrapper = "mesa";
    installScripts = [ "mesa" ];
  };

  programs.zsh.shellAliases = {
    # Enable GPU compositing + VA-API decode path for smoother video playback.
    brave = "nixGLMesa brave --use-gl=desktop --ignore-gpu-blocklist --enable-gpu-rasterization --enable-zero-copy --enable-features=VaapiVideoDecoder,VaapiIgnoreDriverChecks --disable-features=UseChromeOSDirectVideoDecoder";
    # Force Electron apps to prefer hardware rendering on older iGPU laptops.
    code = "nixGLMesa code --use-gl=desktop --ignore-gpu-blocklist --enable-gpu-rasterization --enable-zero-copy --ozone-platform-hint=auto";
  };

  # Add user-specific packages here.
  # home.packages = with pkgs; [
  #   
  # ];

  # Add machine-specific home-manager settings here.
}
