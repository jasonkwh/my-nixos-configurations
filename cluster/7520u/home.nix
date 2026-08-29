{ config, pkgs, nixpkgs-master, ... }:

{
  home.packages = with pkgs; [
    discord
    slack
    ffmpeg
    shntool
    flac
    calibre
    vlc
    # nixos-26.05 pins rpi-imager 2.0.9, which fails to launch on Qt 6.10
    # (upstream WritingStep.qml missing Material import, issue #1553).
    # nixpkgs master has 2.0.10 without the bug — take it from there.
    (nixpkgs-master.legacyPackages.${pkgs.system}.rpi-imager)
    beekeeper-studio
    postman
    pulumi
    vscode
    # nixpkgs calls wrapGAppsHook from buildCommand before the fixup phase,
    # where its required $output context is unavailable.  The hook still runs
    # normally during fixup, so remove only the obsolete early invocation.
    (mongodb-compass.overrideAttrs (old: {
      buildCommand = pkgs.lib.replaceStrings [
        "wrapGAppsHook $out/bin/mongodb-compass"
      ] [ "" ] old.buildCommand;
    }))
  ];
}
