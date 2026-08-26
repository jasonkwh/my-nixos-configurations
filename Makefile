# NixOS flake helpers
#
#   make upgrade                # rebuild + activate current hostname
#   make boot                   # install for next reboot (also cleans /boot)
#   make jasonkwh-7520u         # explicit host
#   make build jasonkwh-7520u   # same (build is a no-op when a host is named)
#   make update                 # update flake inputs
#   make gc                     # delete old generations + refresh bootloader
#   make live                   # build the graphical Live USB ISO
#   make jasonkwh-live          # alias for make live
#   make syncthing-init         # one-time: pre-generate syncthing identity + print device ID

HOSTS := jasonkwh-7520u jasonkwh-7300u jasonkwh-bcm2711
HOST  ?= $(shell hostname)
EXPLICIT_HOST := $(filter $(HOSTS),$(MAKECMDGOALS))

.PHONY: help upgrade boot build update gc live jasonkwh-live bcm2711-image syncthing-init $(HOSTS)
.DEFAULT_GOAL := help

help:
	@printf '%s\n' \
		'HOST=$(HOST)  (override: make upgrade HOST=jasonkwh-7520u)' \
		'' \
		'make upgrade             rebuild and activate' \
		'make boot                rebuild for next reboot (cleans /boot)' \
		'make update              nix flake update' \
		'make gc                  nix-collect-garbage -d + boot refresh' \
		'make live                build the graphical Live USB ISO' \
		'make jasonkwh-live       alias for make live' \
		'make bcm2711-image       build the Pi 4B SD-card image' \
		'make $(HOSTS)  upgrade that host'

define nixos-rebuild
	sudo /run/current-system/sw/bin/nixos-rebuild $(1) --flake $$(pwd)/#$(2) --impure
endef

# `make build` alone → upgrade current host
# `make build jasonkwh-7520u` → host target does the work; build is a no-op
ifeq ($(EXPLICIT_HOST),)
upgrade build:
	$(call nixos-rebuild,switch,$(HOST))
else
build:
	@:
upgrade:
	$(call nixos-rebuild,switch,$(HOST))
endif

boot:
	$(call nixos-rebuild,boot,$(or $(EXPLICIT_HOST),$(HOST)))

update:
	nix flake update

gc:
	NCG=/run/current-system/sw/bin/nix-collect-garbage; \
	sudo "$$NCG" -d
	$(call nixos-rebuild,boot,$(or $(EXPLICIT_HOST),$(HOST)))

live:
	nix build --impure --accept-flake-config .#shengos-live-iso

jasonkwh-live: live

# SD-card image for the bcm2711 (Raspberry Pi 4B) headless node.
# Cross-built on this x86 host via QEMU binfmt emulation; flash the
# resulting .img to a card with e.g. `sudo dd if=<img> of=/dev/sdX bs=4M`.
bcm2711-image:
	nix build --impure --accept-flake-config \
	  .#nixosConfigurations.jasonkwh-bcm2711.config.system.build.images.sd-card
	@printf '\nImage: ls result/*.img.zst — flash with: zstd -d <img> && sudo dd if=<img> of=/dev/sdX bs=4M\n'

# One-time bootstrap for services.syncthing: generate the device identity
# before the first `make upgrade`, so the real device ID can be pasted into
# cluster/common/configuration.nix. Safe to re-run (idempotent).
syncthing-init:
	sudo nix run nixpkgs#syncthing -- generate --home=/var/lib/syncthing-hermes/.config/syncthing
	sudo chown -R hermes:hermes /var/lib/syncthing-hermes
	@printf '\n^^^ Device ID for $(HOST) is on the "Calculated device ID" line above — paste it into configuration.nix\n'

$(HOSTS):
	$(call nixos-rebuild,switch,$@)
