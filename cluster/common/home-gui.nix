{ pkgs, ... }:

{
  # Desktop GUI apps shared by NixOS laptops only.
  home.packages = with pkgs; [
    boxbuddy
    libreoffice-qt
    warp
    zoom-us
    brave
    code-cursor

    # Brave with CDP debugging port for Hermes browser tools (on-demand).
    # Separate user-data-dir is mandatory: Chromium 136+ silently refuses
    # --remote-debugging-port on the default profile.
    (writeShellScriptBin "brave-debug" ''
      exec ${brave}/bin/brave \
        --remote-debugging-port=9222 \
        --user-data-dir=$HOME/.hermes/brave-debug "$@"
    '')
  ];
}
