{ config, pkgs, ... }:

{
  xdg.configFile."pipewire/pipewire.conf.d/99-speaker-tuning.conf".text = ''
    context.modules = [
      { name = libpipewire-module-filter-chain
        flags = [ nofail ]
        args = {
          node.description = "Built-in Speaker Tuning"
          media.name       = "Built-in Speaker Tuning"
          # These drivers cannot move air below ~180 Hz. A 140 Hz tone still
          # displaces the cone, and that excursion modulates the mids. Bankstown
          # sums its harmonics onto the unfiltered dry signal (final_hp applies
          # to the harmonics only), so the high-pass after it is what keeps the
          # cone out of that band.
          filter.graph = {
            nodes = [
              { type = lv2 name = bass
                plugin = "https://chadmed.au/bankstown"
                control = {
                  # Added on top of the dry mids, not a wet/dry mix. 3.0 was a
                  # second copy of the 180-600 Hz band at +9.5 dB. Nudge toward
                  # 1.6 if the pitch illusion is too faint.
                  "amt"        = 1.2
                  # Fundamentals the cone cannot play. The 5th of 60 Hz is 300 Hz
                  # and clears the high-pass; Bankstown low-passes harmonics at
                  # 3x ceil, so they stop at 540 Hz instead of spraying the mids.
                  "floor"      = 60.0
                  "ceil"       = 180.0
                  "final_hp"   = 180.0
                  # 1 = odd harmonics only. The even path is a half-wave stage,
                  # and for this band it lands at 120-180 Hz.
                  "blend"      = 1.0
                  "sat_second" = 0.0
                  "sat_third"  = 1.5
                }
              }
              # 24 dB/oct. About 12 dB down at 140 Hz, within 1 dB by 300 Hz.
              { type = builtin name = hp label = param_eq
                config = {
                  filters = [
                    { type = bq_highpass freq = 180 q = 0.7071 gain = 0 }
                    { type = bq_highpass freq = 180 q = 0.7071 gain = 0 }
                  ]
                }
              }
            ]
            links = [
              { output = "bass:out_l" input = "hp:In 1" }
              { output = "bass:out_r" input = "hp:In 2" }
            ]
            inputs  = [ "bass:in_l" "bass:in_r" ]
            outputs = [ "hp:Out 1"  "hp:Out 2" ]
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
