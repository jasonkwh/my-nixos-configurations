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
#   make secrets-backup         # encrypt ~/.secrets as ./secrets.tar.enc
#   make secrets-restore        # restore ~/.secrets from ./secrets.tar.enc

HOSTS := jasonkwh-7520u jasonkwh-7300u jasonkwh-2450m jasonkwh-3210m jasonkwh-1650v2 jasonkwh-bcm2711
LOCAL_HOST := $(shell hostname)
HOST  ?= $(LOCAL_HOST)
SECRETS_ARCHIVE ?= secrets.tar.enc
EXPLICIT_HOST := $(filter $(HOSTS),$(MAKECMDGOALS))

.PHONY: help upgrade boot build update gc image syncthing-init headless-env secrets-backup secrets-restore $(HOSTS)
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
		'make secrets-backup      encrypt ~/.secrets (SECRETS_ARCHIVE=secrets.tar.enc)' \
		'make secrets-restore     restore ~/.secrets, including modes and ACLs' \
		'make $(HOSTS)  upgrade that host'

define nixos-rebuild
	sudo /run/current-system/sw/bin/nixos-rebuild $(1) --impure $(REBUILD_BUILDERS) --flake $$(pwd)/#$(2)
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
# --impure on nix build: SECRETS_* and REPO_GIT_ARCHIVE enter via
# builtins.getEnv at eval time. Nix filters .git from flake sources, so the
# image recipe adds it to the store separately and the image restores it.
# Probe flake builders (from hostDefs.isBuilder — no hardcoding) with a short
# TCP check; only reachable hosts go into --builders so an offline peer never
# stalls the build on SSH timeout. Empty list = local-only.
# Only evaluate the flake and probe builders for targets that can actually
# build. Doing this unconditionally delays even lightweight targets such as
# `update` and `syncthing-init`, especially on slower boards.
BUILDER_TARGETS := upgrade boot build gc image $(HOSTS)
REQUESTED_BUILDER_TARGETS := $(filter $(BUILDER_TARGETS),$(MAKECMDGOALS))
ifneq ($(REQUESTED_BUILDER_TARGETS),)
BUILDER_HOST := $(or $(EXPLICIT_HOST),$(HOST))
REMOTE_BUILDERS := $(shell bash misc/remote-builders.sh '$(BUILDER_HOST)')
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
	test -e .git || { echo 'image: current directory is not a Git worktree'; exit 1; }; \
	GIT_TAR=$$(mktemp /tmp/shengos-git.XXXXXX.tar); \
	trap 'rm -f "$$GIT_TAR" "$$SEAL_TAR" "$$SEAL_ENC"' EXIT; \
	tar -cf "$$GIT_TAR" .git; \
	GIT_PATH=$$(nix store add-file "$$GIT_TAR"); \
	if [ -n "$(SECRETS_SKIP)" ]; then \
	  echo 'image: building WITHOUT baked secrets (SECRETS_SKIP=1)'; \
	  REPO_GIT_ARCHIVE=$$GIT_PATH nix build $(BUILDERS_FLAG) --impure --accept-flake-config \
	    .#nixosConfigurations.$(IMG_HOST).config.system.build.images.sd-card; \
	elif [ -d /home/jasonkwh/.secrets ]; then \
	  SEAL_TAR=$$(mktemp /tmp/.shengos-seal.XXXXXX); \
	  SEAL_ENC=$$(mktemp /tmp/shengos-secrets.XXXXXX.tar.enc); \
	  tar -cf "$$SEAL_TAR" -C /home/jasonkwh/.secrets .; \
	  printf 'Machine password (board login/sudo for jasonkwh + root): '; \
	  read -rs IMG_PASS; echo; \
	  SEAL_PASS=$$IMG_PASS openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -salt \
	    -in "$$SEAL_TAR" -out "$$SEAL_ENC" -pass env:SEAL_PASS; \
	  rm -f "$$SEAL_TAR"; \
	  SEAL_PATH=$$(nix store add-file "$$SEAL_ENC"); \
	  SECRETS_ENC=$$SEAL_PATH SECRETS_PASS=$$IMG_PASS REPO_GIT_ARCHIVE=$$GIT_PATH \
	    nix build $(BUILDERS_FLAG) --impure --accept-flake-config \
	    .#nixosConfigurations.$(IMG_HOST).config.system.build.images.sd-card; \
	else \
	  echo 'image: no ~/.secrets — building without baked secrets'; \
	  REPO_GIT_ARCHIVE=$$GIT_PATH nix build $(BUILDERS_FLAG) --impure --accept-flake-config \
	    .#nixosConfigurations.$(IMG_HOST).config.system.build.images.sd-card; \
	fi
	@printf '\nImage: ls result/sd-image/*.img.zst\n'

# One-time bootstrap for services.syncthing: generate the device identity
# before the first `make upgrade`, so the real device ID can be pasted into
# the host's `syncthingId` in flake.nix. Safe to re-run (idempotent).
syncthing-init:
	sudo nix run nixpkgs#syncthing -- generate --home=/var/lib/syncthing-hermes/.config/syncthing
	sudo chown -R hermes:hermes /var/lib/syncthing-hermes
	@printf '\n^^^ Device ID for $(HOST) is on the "Calculated device ID" line above — paste it into flake.nix hostDefs\n'

# Export the build host's live Wi-Fi credentials (and optionally a Tailscale
# auth key) into ~/.secrets/headless-env, read by wifi-home.nix /
# tailscale-enrol.nix on headless boards and baked into SD images.
headless-env:
	bash misc/export-headless-env.sh

# Stream directly through OpenSSL so no unencrypted archive is written to disk.
# GNU tar's ACL and xattr flags preserve the access required by service users.
secrets-backup:
	@test -d "$$HOME/.secrets" || { echo 'secrets-backup: ~/.secrets does not exist'; exit 1; }
	@bash -o pipefail -c 'umask 077; tar --create --acls --xattrs --file=- -C "$$HOME" .secrets | openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -salt -out "$(SECRETS_ARCHIVE)"'
	@printf 'Encrypted secrets written to %s\n' "$(SECRETS_ARCHIVE)"

secrets-restore:
	@test -f "$(SECRETS_ARCHIVE)" || { echo 'secrets-restore: $(SECRETS_ARCHIVE) does not exist'; exit 1; }
	@bash -o pipefail -c 'openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -in "$(SECRETS_ARCHIVE)" | tar --extract --acls --xattrs --file=- -C "$$HOME"'
	@printf 'Secrets restored to %s\n' "$$HOME/.secrets"

$(HOSTS):
	$(if $(filter image,$(MAKECMDGOALS)),@:,$(call nixos-rebuild,switch,$@))
