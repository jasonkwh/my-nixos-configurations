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

.PHONY: help upgrade boot build update gc live jasonkwh-live image syncthing-init $(HOSTS)
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
		'make image <host>        build that host SD-card image (e.g. jasonkwh-bcm2711)' \
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

# SD-card image for a host (e.g. `make image jasonkwh-bcm2711`).
# Cross-built on this x86 host via QEMU binfmt emulation; flash the
# resulting .img.zst to a card: zstd -d <img> && sudo dd if=<img> of=/dev/sdX bs=4M
image:
	@test -n "$(filter-out image,$(MAKECMDGOALS))" || { echo 'usage: make image jasonkwh-<host>'; exit 1; }
	nix build --impure --accept-flake-config \
	  .#nixosConfigurations.$(filter-out image,$(MAKECMDGOALS)).config.system.build.images.sd-card
	@printf '\nImage: ls result/*.img.zst\n'

# One-time bootstrap for services.syncthing: generate the device identity
# before the first `make upgrade`, so the real device ID can be pasted into
# cluster/common/configuration.nix. Safe to re-run (idempotent).
syncthing-init:
	sudo nix run nixpkgs#syncthing -- generate --home=/var/lib/syncthing-hermes/.config/syncthing
	sudo chown -R hermes:hermes /var/lib/syncthing-hermes
	@printf '\n^^^ Device ID for $(HOST) is on the "Calculated device ID" line above — paste it into configuration.nix\n'

$(HOSTS):
	$(call nixos-rebuild,switch,$@)
