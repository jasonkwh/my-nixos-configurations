{ pkgs, ... }:

let
  cursor = import ./cursor.nix { inherit pkgs; };
in
{
  # GPU-heavy apps shared by GPU-capable NixOS hosts only.
  home.packages = with pkgs; [
    cursor
    ollama
  ];
}
