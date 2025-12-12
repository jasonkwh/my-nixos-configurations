{ config, pkgs, ... }:

{
  # Home Manager standalone configuration for distrobox
  # Works on: SteamOS (Steam Deck, Steam Machine), Fedora Silverblue, or any immutable OS
  # 
  # First-time setup:
  # 1. Create distrobox: distrobox create --name fedora-dev --image fedora:latest --init
  # 2. Enter distrobox: distrobox enter fedora-dev
  # 3. Install Nix: sh <(curl -L https://nixos.org/nix/install) --daemon
  # 4. Enable flakes: echo "experimental-features = nix-command flakes" | sudo tee -a /etc/nix/nix.conf
  # 5. Restart shell (exit and re-enter distrobox)
  # 6. Clone this repo and run (first time only):
  #    nix run github:nix-community/home-manager/release-25.11 -- switch --flake .#jasonkwh-distrobox
  #
  # Subsequent updates:
  #    make build jasonkwh-distrobox
  #    # or: home-manager switch --flake .#jasonkwh-distrobox

  imports = [
    ../common/home.nix
  ];

  # Add distrobox-specific packages here
  # home.packages = with pkgs; [
  #   
  # ];
}
