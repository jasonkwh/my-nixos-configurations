#!/etc/profiles/per-user/jasonkwh/bin/bash

cd /etc/nixos
sudo nix flake update
sudo nixos-rebuild switch --flake /etc/nixos#nixos-jasonkwh --upgrade-all
