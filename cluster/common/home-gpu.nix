{ pkgs, ... }:

let
  cursor = import ./cursor.nix { inherit pkgs; };

  # Wrap brave to inject performance flags. The NixOS brave wrapper does not
  # read ~/.config/brave-flags.conf (that is an AUR convention), so makeWrapper
  # is the correct approach.
  # --process-per-site: reuse one renderer process per domain instead of per tab,
  #   reducing the default ~19 renderer sprawl significantly.
  # --enable-tab-discarding: freeze background tabs under memory pressure.
  # --enable-features=MemoryPressureBasedSourceBufferGC: release media buffers faster.
  brave = pkgs.symlinkJoin {
    name = "brave";
    paths = [ pkgs.brave ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/brave \
        --add-flags "--process-per-site" \
        --add-flags "--enable-tab-discarding" \
        --add-flags "--enable-features=MemoryPressureBasedSourceBufferGC"

      # The .desktop files are symlinks into the read-only nix store; copy them
      # to make them writable, then patch the hardcoded store path to use the
      # wrapper binary instead (otherwise KDE launches the unwrapped binary).
      for f in $out/share/applications/*.desktop; do
        cp --remove-destination "$(readlink -f "$f")" "$f"
        substituteInPlace "$f" \
          --replace-warn "${pkgs.brave}/bin/brave" "$out/bin/brave"
      done
    '';
  };
in
{
  # GPU-heavy apps shared by GPU-capable NixOS hosts only.
  home.packages = with pkgs; [
    brave
    cursor
    ollama
  ];
}
