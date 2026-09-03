# NixOS flake helpers
#
#   make upgrade                # rebuild + activate current hostname
#   make boot                   # install for next reboot (also cleans /boot)
#   make jasonkwh-7520u         # explicit host
#   make build jasonkwh-7520u   # same (build is a no-op when a host is named)
#   make update                 # update flake inputs
#   make gc                     # delete old generations + refresh bootloader

#   make syncthing-init         # one-time: pre-generate syncthing identity + print device ID
#   make headless-env           # export Wi-Fi/Tailscale secrets for headless boards (~/.secrets/headless-env)

HOSTS := jasonkwh-7520u jasonkwh-7300u jasonkwh-1650v2 jasonkwh-bcm2711 jasonkwh-bcm2710a1
HOST  ?= $(shell hostname)
EXPLICIT_HOST := $(filter $(HOSTS),$(MAKECMDGOALS))

.PHONY: help upgrade boot build update gc image syncthing-init headless-env $(HOSTS)
.DEFAULT_GOAL := help

help:
	@printf '%s\n' \
		'HOST=$(HOST)  (override: make upgrade HOST=jasonkwh-7520u)' \
		'' \
		'make upgrade             rebuild and activate' \
		'make boot                rebuild for next reboot (cleans /boot)' \
		'make update              nix flake update' \
		'make gc                  nix-collect-garbage -d + boot refresh' \

		'make image <host>        build that host SD-card image (e.g. jasonkwh-bcm2711)' \
		'make $(HOSTS)  upgrade that host'

define nixos-rebuild
	sudo /run/current-system/sw/bin/nixos-rebuild $(1) $(REBUILD_BUILDERS) --flake $$(pwd)/#$(2)
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

# SD-card image: make image HOST=jasonkwh-bcm2711
# `make image jasonkwh-bcm2711` is also supported. Cross-built natively on
# x86 (no QEMU); flash the resulting .img.zst to a card:
# zstd -d <img> && sudo dd if=<img> of=/dev/sdX bs=4M
# Prompts once for the machine password: ~/.secrets is sealed with it and
# baked into the image (ciphertext), and it becomes the login password of
# both jasonkwh and root on the board.  SECRETS_SKIP=1 builds without.
IMG_HOST := $(if $(filter command line,$(origin HOST)),$(HOST),$(filter $(HOSTS),$(filter-out image,$(MAKECMDGOALS))))
# --impure on nix build: SECRETS_* enter via builtins.getEnv at eval time;
# pure eval returns empty and the image silently bakes no secrets.
# Probe flake builders (from hostDefs.isBuilder — no hardcoding) with a short
# TCP check; only reachable hosts go into --builders so an offline peer never
# stalls the build on SSH timeout. Empty list = local-only.
# Only evaluate the flake and probe builders for targets that can actually
# build. Doing this unconditionally delays even lightweight targets such as
# `update` and `syncthing-init`, especially on slower boards.
BUILDER_TARGETS := upgrade boot build gc image $(HOSTS)
ifneq ($(filter $(BUILDER_TARGETS),$(MAKECMDGOALS)),)
REMOTE_BUILDERS := $(shell bash cluster/misc/remote-builders.sh)
BUILDERS_FLAG := $(if $(REMOTE_BUILDERS),--builders '$(REMOTE_BUILDERS)',--builders '')
# Same probe for nixos-rebuild: --builders is a nix.conf-style key, supported
# as a CLI option on rebuild too.
REBUILD_BUILDERS := $(if $(REMOTE_BUILDERS),--builders '$(REMOTE_BUILDERS)',--builders '')
endif

# The encrypted archive must first become a store input: build sandboxes
# cannot read a bare /tmp path. Dollar signs are doubled for Make so command
# substitution and shell variables reach the shell unchanged.
image:
	@test -n "$(IMG_HOST)" || { echo 'usage: make image HOST=jasonkwh-<host>'; exit 1; }
	@set -e; \
	if [ -n "$(SECRETS_SKIP)" ]; then \
	  echo 'image: building WITHOUT baked secrets (SECRETS_SKIP=1)'; \
	  nix build $(BUILDERS_FLAG) --accept-flake-config \
	    .#nixosConfigurations.$(IMG_HOST).config.system.build.images.sd-card; \
	elif [ -d /home/jasonkwh/.secrets ]; then \
	  SEAL_TAR=$$(mktemp /tmp/.shengos-seal.XXXXXX); \
	  SEAL_ENC=$$(mktemp /tmp/shengos-secrets.XXXXXX.tar.enc); \
	  trap 'rm -f "$$SEAL_TAR" "$$SEAL_ENC"' EXIT; \
	  tar -cf "$$SEAL_TAR" -C /home/jasonkwh/.secrets .; \
	  printf 'Machine password (board login/sudo for jasonkwh + root): '; \
	  read -rs IMG_PASS; echo; \
	  SEAL_PASS=$$IMG_PASS openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -salt \
	    -in "$$SEAL_TAR" -out "$$SEAL_ENC" -pass env:SEAL_PASS; \
	  rm -f "$$SEAL_TAR"; \
	  SEAL_PATH=$$(nix store add-file "$$SEAL_ENC"); \
	  SECRETS_ENC=$$SEAL_PATH SECRETS_PASS=$$IMG_PASS \
	    nix build $(BUILDERS_FLAG) --impure --accept-flake-config \
	    .#nixosConfigurations.$(IMG_HOST).config.system.build.images.sd-card; \
	else \
	  echo 'image: no ~/.secrets — building without baked secrets'; \
	  nix build $(BUILDERS_FLAG) --accept-flake-config \
	    .#nixosConfigurations.$(IMG_HOST).config.system.build.images.sd-card; \
	fi
	@printf '\nImage: ls result/sd-image/*.img.zst\n'

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
	$(if $(filter image,$(MAKECMDGOALS)),@:,$(call nixos-rebuild,switch,$@))
