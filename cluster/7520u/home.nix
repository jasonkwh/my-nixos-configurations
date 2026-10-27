{ config, pkgs, ... }:

{
  xdg.configFile."pipewire/pipewire.conf.d/99-speaker-tuning.conf".text = ''
    context.modules = [
      { name = libpipewire-module-filter-chain
        flags = [ nofail ]
        args = {
          node.description = "Built-in Speaker Tuning"
          media.name       = "Built-in Speaker Tuning"
          filter.graph = {
            nodes = [
              { type = lv2 name = bass
                plugin = "https://chadmed.au/bankstown"
                control = {
                  "amt"        = 3.0
                  "floor"      = 60.0
                  "ceil"       = 200.0
                  "final_hp"   = 150.0
                  "blend"      = 0.55
                  "sat_second" = 1.0
                  "sat_third"  = 0.7
                }
              }
            ]
            inputs  = [ "bass:in_l"  "bass:in_r"  ]
            outputs = [ "bass:out_l" "bass:out_r" ]
          }
          audio.channels = 2
          audio.position = [ FL FR ]
          capture.props = {
            node.name        = "effect_input.speaker"
            media.class      = Audio/Sink
            priority.session = 2000
          }
          playback.props = {
            node.name    = "effect_output.speaker"
            node.passive = true
            node.target  = "alsa_output.pci-0000_03_00.6.HiFi__Speaker__sink"
          }
        }
      }
    ]
  '';

  home.packages = with pkgs; [
    calibre
    vlc
    beekeeper-studio
    postman
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
