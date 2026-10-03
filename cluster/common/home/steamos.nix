# SteamOS starts Desktop Mode without a NixOS session, so Plasma never
# sees the Home Manager profile. These scripts run before the shell.
{ config, ... }:

{
  home.sessionVariables.ELECTRON_OZONE_PLATFORM_HINT = "auto";

  home.file.".config/plasma-workspace/env/home-manager.sh".text = ''
    export PATH="${config.home.profileDirectory}/bin''${PATH:+:}$PATH"
    export XDG_DATA_DIRS="${config.home.profileDirectory}/share''${XDG_DATA_DIRS:+:}$XDG_DATA_DIRS"
    export ELECTRON_OZONE_PLATFORM_HINT="auto"
  '';
}
