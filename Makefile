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

HOSTS := jasonkwh-7520u jasonkwh-7300u
HOST  ?= $(shell hostname)
EXPLICIT_HOST := $(filter $(HOSTS),$(MAKECMDGOALS))

.PHONY: help upgrade boot build update gc live jasonkwh-live $(HOSTS)
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

$(HOSTS):
	$(call nixos-rebuild,switch,$@)
