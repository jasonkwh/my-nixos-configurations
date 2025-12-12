.PHONY: build update jasonkwh-7520u jasonkwh-7300u

# Usage: make build jasonkwh-7520u
#        make build jasonkwh-7300u
#        make update

build: ;

update:
	sudo nix flake update

jasonkwh-7520u:
	sudo nixos-rebuild switch --flake .#jasonkwh-7520u --upgrade-all

jasonkwh-7300u:
	sudo nixos-rebuild switch --flake .#jasonkwh-7300u --upgrade-all
