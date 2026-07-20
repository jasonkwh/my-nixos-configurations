# NixOS flake helpers
#
#   make switch                 # rebuild + activate current hostname
#   make boot                   # install for next reboot (also cleans /boot)
#   make jasonkwh-7520u         # explicit host
#   make build jasonkwh-7520u   # same (build is a no-op when a host is named)
#   make update                 # update flake inputs
#   make gc                     # delete old generations + refresh bootloader

HOSTS := jasonkwh-7520u jasonkwh-7300u
HOST  ?= $(shell hostname)
EXPLICIT_HOST := $(filter $(HOSTS),$(MAKECMDGOALS))

.PHONY: help switch boot build update gc $(HOSTS)
.DEFAULT_GOAL := help

help:
	@printf '%s\n' \
		'HOST=$(HOST)  (override: make switch HOST=jasonkwh-7520u)' \
		'' \
		'make switch              rebuild and activate' \
		'make boot                rebuild for next reboot (cleans /boot)' \
		'make update              nix flake update' \
		'make gc                  nix-collect-garbage -d + boot refresh' \
		'make $(HOSTS)  switch that host'

define nixos-rebuild
	sudo nixos-rebuild $(1) --flake .#$(2) --impure
endef

# `make build` alone → switch current host
# `make build jasonkwh-7520u` → host target does the work; build is a no-op
ifeq ($(EXPLICIT_HOST),)
switch build:
	$(call nixos-rebuild,switch,$(HOST))
else
build:
	@:
switch:
	$(call nixos-rebuild,switch,$(HOST))
endif

boot:
	$(call nixos-rebuild,boot,$(or $(EXPLICIT_HOST),$(HOST)))

update:
	sudo nix flake update

gc:
	sudo nix-collect-garbage -d
	$(call nixos-rebuild,boot,$(or $(EXPLICIT_HOST),$(HOST)))

$(HOSTS):
	$(call nixos-rebuild,switch,$@)
