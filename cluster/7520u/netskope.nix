# Netskope client (work VPN/ZTNA agent), opt-in via shengos.netskope.enable.
# The vendor .run is a hard-coded-FHS installer (/bin/bash, /bin/rm) that
# cannot run on bare NixOS; wrapped with buildFHSEnv. Disable = gone on next rebuild.
{ config, lib, pkgs, ... }:

let
  cfg = config.shengos.netskope;
  installerRun = ./NSClient_addon-avayaglobal.goskope.com_29441_efA700VF8CWUyZOzKmHl_OuFpY3S9M0g17TsuAfI22p6WT8R9J1d1dqh72jfj_.run;

  netskope-installer = pkgs.buildFHSEnv {
    name = "netskope-installer";
    targetPkgs = pkgs: with pkgs; [
      bash
      coreutils
      curl
      procps
      systemd
      zlib
      openssl
    ];
    runScript = "bash ${installerRun}";
  };
in
{
  options.shengos.netskope.enable = lib.mkEnableOption "Netskope client installer (FHS-wrapped)";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ netskope-installer ];
  };
}
