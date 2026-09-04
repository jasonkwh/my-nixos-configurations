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
LOCAL_HOST := $(shell hostname)
HOST  ?= $(LOCAL_HOST)
EXPLICIT_HOST := $(filter $(HOSTS),$(MAKECMDGOALS))
TARGET_HOST := $(or $(EXPLICIT_HOST),$(HOST))
OFFLOAD_HOST ?= jasonkwh-bcm2711
OFFLOAD_SSH  := jasonkwh@$(OFFLOAD_HOST).tail0c0276.ts.net
OFFLOAD_STORE := ssh-ng://$(OFFLOAD_SSH)
# $$ is the recipe shell's pid: two concurrent runs must not share a source
# tree, since each one wipes the directory before unpacking into it.
OFFLOAD_TMP := /tmp/shengos-offload-$(TARGET_HOST).$$$$
# Indirect GC root on the builder. Without it the closure is unreferenced
# between the remote build and the copy, so bcm2711's weekly gc can collect it.
OFFLOAD_LINK := /home/jasonkwh/.shengos-offload-$(TARGET_HOST)

# bcm2710a1 has 512MB: evaluating its own configuration exhausts RAM + zram,
# so rebuilds of that board, run from that board, go through bcm2711
# (NO_OFFLOAD=1 forces the slow local path if bcm2711 is gone for good).
# It equally cannot evaluate another host, and activating another host's
# system here would be wrong, so those invocations are refused. Every other
# machine is unconditionally `local` and keeps its previous behaviour.
ifeq ($(LOCAL_HOST),jasonkwh-bcm2710a1)
REBUILD_MODE := $(if $(filter jasonkwh-bcm2710a1,$(TARGET_HOST)),$(if $(NO_OFFLOAD),local,offload),refuse)
else
REBUILD_MODE := local
endif

.PHONY: help upgrade boot build update gc image syncthing-init headless-env $(HOSTS)
.DEFAULT_GOAL := help

help:
	@printf '%s\n' \
		'HOST=$(HOST)  (override: make upgrade HOST=jasonkwh-7520u)' \
		'' \
		'make upgrade             rebuild and activate (bcm2710a1 uses bcm2711)' \
		'make boot                rebuild for next reboot (cleans /boot)' \
		'make update              nix flake update' \
		'make gc                  nix-collect-garbage -d + boot refresh' \
		'make image <host>        build that host SD-card image (e.g. jasonkwh-bcm2711)' \
		'make $(HOSTS)  upgrade that host'

define nixos-rebuild
	sudo /run/current-system/sw/bin/nixos-rebuild $(1) --impure $(REBUILD_BUILDERS) --flake $$(pwd)/#$(2)
endef

# Low-memory path: stream the source tree to bcm2711 without invoking Nix
# locally, evaluate and build there, copy the finished closure back, then
# activate it here with $(1) (switch or boot). --impure is load-bearing:
# without it builtins.currentSystem is unavailable and the flake falls back to
# treating the build as an x86 cross-compile. Paths bcm2711 built itself are
# unsigned, so the copy needs --no-check-sigs, which the daemon only honours
# because jasonkwh is in nix.settings.trusted-users.
define offload-rebuild
	@set -eu; \
	ssh -o ConnectTimeout=5 -o BatchMode=yes '$(OFFLOAD_SSH)' true 2>/dev/null || { \
	  echo '$(OFFLOAD_HOST) is unreachable, and $(TARGET_HOST) builds through it.'; \
	  echo 'Bring it online, or force the slow local path with NO_OFFLOAD=1.'; \
	  exit 1; \
	}; \
	echo "Streaming configuration to $(OFFLOAD_HOST)..."; \
	SYSTEM_PATH=$$(tar --exclude='./.git' --exclude='./result' --exclude='./result-*' -cf - . \
	  | ssh '$(OFFLOAD_SSH)' \
	    "set -eu; \
	     rm -rf '$(OFFLOAD_TMP)'; \
	     mkdir -p '$(OFFLOAD_TMP)'; \
	     trap 'rm -rf $(OFFLOAD_TMP)' EXIT; \
	     tar -xf - -C '$(OFFLOAD_TMP)'; \
	     nix build --impure --accept-flake-config --print-out-paths \
	       --out-link '$(OFFLOAD_LINK)' \
	       '$(OFFLOAD_TMP)#nixosConfigurations.$(TARGET_HOST).config.system.build.toplevel'"); \
	test -n "$$SYSTEM_PATH"; \
	echo "Copying the finished system back to $(TARGET_HOST)..."; \
	nix copy --no-check-sigs --from '$(OFFLOAD_STORE)' "$$SYSTEM_PATH"; \
	ssh '$(OFFLOAD_SSH)' "rm -f '$(OFFLOAD_LINK)'"; \
	echo "Activating $$SYSTEM_PATH ($(1))..."; \
	sudo /run/current-system/sw/bin/nix-env \
	  --profile /nix/var/nix/profiles/system --set "$$SYSTEM_PATH"; \
	sudo "$$SYSTEM_PATH/bin/switch-to-configuration" $(1)
endef

define refuse-rebuild
	@echo 'Refusing to build $(1) on jasonkwh-bcm2710a1: this board cannot'; \
	echo 'evaluate another host, and activating that system here would be wrong.'; \
	echo 'Run it from $(1) itself, or from a laptop.'; \
	exit 1
endef

# Every rebuild entry point goes through this, so boot/gc/<host> get the same
# treatment as upgrade instead of quietly OOMing on the small board.
rebuild-local = $(call nixos-rebuild,$(1),$(2))
rebuild-offload = $(call offload-rebuild,$(1))
rebuild-refuse = $(call refuse-rebuild,$(2))
rebuild = $(call rebuild-$(REBUILD_MODE),$(1),$(2))

# `make build` alone → upgrade current host
# `make build jasonkwh-7520u` → host target does the work; build is a no-op
ifeq ($(EXPLICIT_HOST),)
upgrade build:
	$(call rebuild,switch,$(HOST))
else
build:
	@:
upgrade:
	$(call rebuild,switch,$(HOST))
endif

boot:
	$(call rebuild,boot,$(TARGET_HOST))

update:
	nix flake update

gc:
	NCG=/run/current-system/sw/bin/nix-collect-garbage; \
	sudo "$$NCG" -d
	$(call rebuild,boot,$(TARGET_HOST))

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
ifneq ($(REBUILD_MODE),local)
# The offloaded path does its own transfer and remote build, so no local
# nixos-rebuild runs and only `image` still needs the probe.
REQUESTED_BUILDER_TARGETS := $(filter image,$(REQUESTED_BUILDER_TARGETS))
endif
ifneq ($(REQUESTED_BUILDER_TARGETS),)
BUILDER_HOST := $(or $(EXPLICIT_HOST),$(HOST))
REMOTE_BUILDERS := $(shell bash cluster/misc/remote-builders.sh '$(BUILDER_HOST)')
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
	bash cluster/misc/export-headless-env.sh

$(HOSTS):
	$(if $(filter image,$(MAKECMDGOALS)),@:,$(call rebuild,switch,$@))
