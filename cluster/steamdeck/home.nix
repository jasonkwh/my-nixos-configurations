{ config, pkgs, ... }:

{
  # Home Manager standalone configuration for Steam Deck (Fedora distrobox)
  # 
  # First-time setup:
  # 1. Create distrobox: distrobox create --name fedora-dev --image fedora:latest --init
  # 2. Enter distrobox: distrobox enter fedora-dev
  # 3. Install Nix: sh <(curl -L https://nixos.org/nix/install) --daemon
  # 4. Enable flakes: echo "experimental-features = nix-command flakes" | sudo tee -a /etc/nix/nix.conf
  # 5. Restart shell (exit and re-enter distrobox)
  # 6. Clone this repo and run (first time only):
  #    nix run github:nix-community/home-manager/release-25.11 -- switch --flake .#jasonkwh-steamdeck
  #
  # Subsequent updates:
  #    make build jasonkwh-steamdeck
  #    # or: home-manager switch --flake .#jasonkwh-steamdeck

  imports = [
    ../common/home.nix
  ];

  # Add steamdeck-specific packages here
  # home.packages = with pkgs; [
  #   
  # ];
}
