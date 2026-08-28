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

HOSTS := jasonkwh-7520u jasonkwh-7300u jasonkwh-bcm2711 jasonkwh-bcm2710a1
HOST  ?= $(shell hostname)
EXPLICIT_HOST := $(filter $(HOSTS),$(MAKECMDGOALS))

.PHONY: help upgrade boot build update gc live jasonkwh-live image seal-secrets syncthing-init $(HOSTS)
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
		'make seal-secrets        encrypt ~/.secrets for the installer (target-user password)' \
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
	elif [ -d /home/jasonkwh/.secrets ] && { [ ! -f shengos-secrets.tar.enc ] || [ /home/jasonkwh/.secrets -nt shengos-secrets.tar.enc ]; }; then \
	  echo 'live: sealing ~/.secrets (stale or missing seal)'; \
	  $(MAKE) --no-print-directory seal-secrets; \
	  SECRETS_ENC=$$(pwd)/shengos-secrets.tar.enc nix build --accept-flake-config .#shengos-live-iso; \
	elif [ -f shengos-secrets.tar.enc ]; then \
	  echo 'live: baking existing shengos-secrets.tar.enc into the ISO (ciphertext)'; \
	  SECRETS_ENC=$$(pwd)/shengos-secrets.tar.enc nix build --accept-flake-config .#shengos-live-iso; \
	else \
	  echo 'live: no ~/.secrets — building without baked secrets'; \
	  nix build --accept-flake-config .#shengos-live-iso; \
	fi

jasonkwh-live: live

# SD-card image for a host (e.g. `make image jasonkwh-bcm2711`).
# Cross-built on this x86 host via QEMU binfmt emulation; flash the
# resulting .img.zst to a card: zstd -d <img> && sudo dd if=<img> of=/dev/sdX bs=4M
# The build host's ~/.secrets is baked into the image when readable.
image:
	@test -n "$(filter-out image,$(MAKECMDGOALS))" || { echo 'usage: make image jasonkwh-<host>'; exit 1; }
	SECRETS_SRC=$(wildcard /home/jasonkwh/.secrets) nix build --accept-flake-config \
	  .#nixosConfigurations.$(filter-out image,$(MAKECMDGOALS)).config.system.build.images.sd-card
	@printf '\nImage: ls result/*.img.zst\n'

# Seal ~/.secrets for the Live installer: tar + AES-256 encrypt with the
# password the NEW machine's user will set at install time.  The ISO stays
# credential-free (ciphertext only); the installer asks for this password
# before it can proceed (cluster/live/configuration.nix).  Re-run after any
# change to ~/.secrets and re-run `make live` to re-bake the ISO.
seal-secrets:
	@test -d /home/jasonkwh/.secrets || { echo 'no ~/.secrets to seal'; exit 1; }
	@if [ -z "$$SEAL_PASS" ]; then \
	  printf 'Seal password (the new machine'\''s login password): '; \
	  read -rs SEAL_PASS; echo; \
	  printf 'Confirm: '; \
	  read -rs SEAL_PASS2; echo; \
	  [ "$$SEAL_PASS" = "$$SEAL_PASS2" ] || { echo 'passwords differ'; exit 1; }; \
	  export SEAL_PASS; \
	fi
	tar -cf /tmp/.shengos-seal.$$ -C /home/jasonkwh .secrets
	SEAL_PASS=$$SEAL_PASS openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -salt \
	  -in /tmp/.shengos-seal.$$ -out shengos-secrets.tar.enc -pass env:SEAL_PASS
	rm -f /tmp/.shengos-seal.$$
	@printf '\nSealed: shengos-secrets.tar.enc — `make live` bakes it into the ISO.\n'

# One-time bootstrap for services.syncthing: generate the device identity
# before the first `make upgrade`, so the real device ID can be pasted into
# cluster/common/configuration.nix. Safe to re-run (idempotent).
syncthing-init:
	sudo nix run nixpkgs#syncthing -- generate --home=/var/lib/syncthing-hermes/.config/syncthing
	sudo chown -R hermes:hermes /var/lib/syncthing-hermes
	@printf '\n^^^ Device ID for $(HOST) is on the "Calculated device ID" line above — paste it into configuration.nix\n'

$(HOSTS):
	$(call nixos-rebuild,switch,$@)
