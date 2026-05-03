.PHONY: build update jasonkwh-7520u jasonkwh-7300u jasonkwh-6267u

# Usage: make build jasonkwh-7520u
#        make build jasonkwh-7300u
#        make build jasonkwh-6267u
#        make update

build: ;

update:
	sudo nix flake update

jasonkwh-7520u:
	sudo nixos-rebuild switch --flake .#jasonkwh-7520u --impure --upgrade-all

jasonkwh-7300u:
	sudo nixos-rebuild switch --flake .#jasonkwh-7300u --impure --upgrade-all

jasonkwh-6267u:
	nix run nixpkgs#home-manager -- switch -b backup --flake .#jasonkwh-6267u
