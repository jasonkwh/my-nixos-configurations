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
#   make headless-env           # export Wi-Fi/Tailscale secrets for headless boards (~/.secrets/headless-env)

HOSTS := jasonkwh-7520u jasonkwh-7300u jasonkwh-bcm2711 jasonkwh-bcm2710a1
HOST  ?= $(shell hostname)
EXPLICIT_HOST := $(filter $(HOSTS),$(MAKECMDGOALS))

.PHONY: help upgrade boot build update gc live jasonkwh-live image syncthing-init headless-env $(HOSTS)
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
	sudo /run/current-system/sw/bin/nixos-rebuild $(1) --flake $$(pwd)/#$(2)
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
	@if [ -n "$(SECRETS_SKIP)" ]; then \
	  echo 'live: building WITHOUT baked secrets (SECRETS_SKIP=1)'; \
	  SECRETS_ENC= nix build --accept-flake-config .#shengos-live-iso; \
	elif [ -d /home/jasonkwh/.secrets ]; then \
	  echo 'live: sealing ~/.secrets and baking it into the ISO (ciphertext)'; \
	  tar -cf /tmp/.shengos-seal.$$$${RANDOM} -C /home/jasonkwh .secrets; \
	  printf 'Seal password (the new machine'\''s login password): '; \
	  read -rs SEAL_PASS; echo; \
	  SEAL_PASS=$$SEAL_PASS openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -salt \
	    -in /tmp/.shengos-seal.$$$${RANDOM} -out shengos-secrets.tar.enc -pass env:SEAL_PASS; \
	  rm -f /tmp/.shengos-seal.*; \
	  SECRETS_ENC=$$(pwd)/shengos-secrets.tar.enc nix build --accept-flake-config .#shengos-live-iso; \
	else \
	  echo 'live: no ~/.secrets — building without baked secrets'; \
	  nix build --accept-flake-config .#shengos-live-iso; \
	fi

jasonkwh-live: live

# SD-card image: make image HOST=jasonkwh-bcm2711
# (HOST= avoids make treating the host as a second goal and triggering a
# pointless sudo rebuild.)  Cross-built natively on x86 (no QEMU); flash the
# resulting .img.zst to a card: zstd -d <img> && sudo dd if=<img> of=/dev/sdX bs=4M
# Prompts once for the machine password: ~/.secrets is sealed with it and
# baked into the image (ciphertext), and it becomes the login password of
# both jasonkwh and root on the board.  SECRETS_SKIP=1 builds without.
IMG_HOST := $(if $(filter command line,$(origin HOST)),$(HOST),$(filter $(HOSTS),$(filter-out image,$(MAKECMDGOALS))))
# --impure on nix build: SECRETS_* enter via builtins.getEnv at eval time;
# pure eval returns empty and the image silently bakes no secrets.
image:
	@test -n "$(IMG_HOST)" || { echo 'usage: make image HOST=jasonkwh-<host>'; exit 1; }
	@if [ -n "$(SECRETS_SKIP)" ]; then \
	  echo 'image: building WITHOUT baked secrets (SECRETS_SKIP=1)'; \
	  nix build --accept-flake-config \
	    .#nixosConfigurations.$(IMG_HOST).config.system.build.images.sd-card; \
	elif [ -d /home/jasonkwh/.secrets ]; then \
	  tar -cf /tmp/.shengos-seal.$$$${RANDOM} -C /home/jasonkwh .secrets; \
	  printf 'Machine password (board login/sudo for jasonkwh + root): '; \
	  read -rs IMG_PASS; echo; \
	  SEAL_PASS=$$IMG_PASS openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -salt \
	    -in /tmp/.shengos-seal.$$$${RANDOM} -out /tmp/shengos-secrets.tar.enc -pass env:SEAL_PASS; \
	  rm -f /tmp/.shengos-seal.*; \
	  SECRETS_ENC=/tmp/shengos-secrets.tar.enc SECRETS_PASS=$$IMG_PASS \
	    nix build --impure --accept-flake-config \
	    .#nixosConfigurations.$(IMG_HOST).config.system.build.images.sd-card; \
	  rm -f /tmp/shengos-secrets.tar.enc; \
	else \
	  echo 'image: no ~/.secrets — building without baked secrets'; \
	  nix build --accept-flake-config \
	    .#nixosConfigurations.$(IMG_HOST).config.system.build.images.sd-card; \
	fi
	@printf '\nImage: ls result/*.img.zst\n'

# One-time bootstrap for services.syncthing: generate the device identity
# before the first `make upgrade`, so the real device ID can be pasted into
# cluster/common/configuration.nix. Safe to re-run (idempotent).
syncthing-init:
	sudo nix run nixpkgs#syncthing -- generate --home=/var/lib/syncthing-hermes/.config/syncthing
	sudo chown -R hermes:hermes /var/lib/syncthing-hermes
	@printf '\n^^^ Device ID for $(HOST) is on the "Calculated device ID" line above — paste it into configuration.nix\n'

# Export the build host's live Wi-Fi credentials (and optionally a Tailscale
# auth key) into ~/.secrets/headless-env, read by wifi-home.nix /
# tailscale-enrol.nix on headless boards and baked into SD images.
headless-env:
	bash cluster/misc/export-headless-env.sh

$(HOSTS):
	$(call nixos-rebuild,switch,$@)
