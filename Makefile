.PHONY: build update jasonkwh-7520u jasonkwh-7300u jasonkwh-distrobox

# Usage: make build jasonkwh-7520u
#        make build jasonkwh-7300u
#        make build jasonkwh-distrobox
#        make update

build: ;

update:
	sudo nix flake update

jasonkwh-7520u:
	sudo nixos-rebuild switch --flake .#jasonkwh-7520u --upgrade-all

jasonkwh-7300u:
	sudo nixos-rebuild switch --flake .#jasonkwh-7300u --upgrade-all

jasonkwh-distrobox:
	home-manager switch --flake .#jasonkwh-distrobox
