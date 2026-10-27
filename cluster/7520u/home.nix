{ config, pkgs, ... }:

{
  xdg.configFile."pipewire/pipewire.conf.d/99-speaker-tuning.conf".text = ''
    context.modules = [
      { name = libpipewire-module-filter-chain
        flags = [ nofail ]
        args = {
          node.description = "Built-in Speaker Tuning"
          media.name       = "Built-in Speaker Tuning"
          # Lid-mic sweep of the raw ALC256 speakers, two levels, repeated.
          # Below 220 Hz the tone is ~20 dB under 1 kHz and the harmonics are
          # as loud as the fundamental. Output becomes real around 300 Hz and
          # linear by 500 Hz, with a strong resonance at 700 Hz. Two Butterworth
          # sections at 320 Hz: about 21 dB down at 180 Hz, 6 dB at the corner,
          # about 1 dB by 500 Hz.
          filter.graph = {
            nodes = [
              { type = builtin name = hp label = param_eq
                config = {
                  filters = [
                    { type = bq_highpass freq = 320 q = 0.7071 gain = 0 }
                    { type = bq_highpass freq = 320 q = 0.7071 gain = 0 }
                  ]
                }
              }
            ]
            inputs  = [ "hp:In 1" "hp:In 2" ]
            outputs = [ "hp:Out 1" "hp:Out 2" ]
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
