# User-level Hermes for SteamOS. HERMES_HOME is under the deck user's
# home, and the gateway is a systemd user service.
{ lib, pkgs, hermesModel, hermesPeerHosts, tailscaleDomain, hostName, homeDirectory, ... }:

{
  programs.hermes-agent.enable = true;

  services.hermes-agent = {
    enable = true;
    gateway.enable = true;
    hermesHome = "${homeDirectory}/.hermes";
  } // import ../hermes/settings.nix {
    inherit lib pkgs hermesModel hermesPeerHosts tailscaleDomain hostName homeDirectory;
    bindApiServer = true;
  } // {
    hermesHomeFiles."SOUL.md" = ../../../misc/SOUL.md;
  };
}
