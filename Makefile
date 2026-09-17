HOSTS := jasonkwh-7520u jasonkwh-7300u jasonkwh-2450m jasonkwh-3210m jasonkwh-1650v2 jasonkwh-bcm2711
LOCAL_HOST := $(shell hostname)
HOST  ?= $(LOCAL_HOST)
SECRETS_ARCHIVE ?= secrets.tar.enc
EXPLICIT_HOST := $(filter $(HOSTS),$(MAKECMDGOALS))

.PHONY: help upgrade boot deploy build update gc image syncthing-init headless-env secrets-backup secrets-restore $(HOSTS)
.DEFAULT_GOAL := help

help:
	@printf '%s\n' \
		'HOST=$(HOST)  (override: make upgrade HOST=jasonkwh-7520u)' \
		'' \
		'make upgrade             rebuild and activate' \
		'make deploy <host>      build (local + online builders), push + switch on target' \
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

# `make build <host>` is a no-op; the host target runs the rebuild.
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

deploy:
	$(call nixos-rebuild,switch --target-host $(or $(EXPLICIT_HOST),$(HOST)),$(or $(EXPLICIT_HOST),$(HOST)))

update:
	nix flake update

gc:
	NCG=/run/current-system/sw/bin/nix-collect-garbage; \
	sudo "$$NCG" -d
	$(call nixos-rebuild,boot,$(or $(EXPLICIT_HOST),$(HOST)))

# Image: make image jasonkwh-bcm2711 (or HOST=). Cross-built on x86; SECRETS_SKIP=1 skips ~/.secrets.
IMG_HOST := $(if $(filter command line,$(origin HOST)),$(HOST),$(filter $(HOSTS),$(filter-out image,$(MAKECMDGOALS))))
# --builders from remote-builders.sh (speed >= this host). Skip for update/secrets/….
BUILDER_TARGETS := upgrade boot deploy build gc image $(HOSTS)
REQUESTED_BUILDER_TARGETS := $(filter $(BUILDER_TARGETS),$(MAKECMDGOALS))
ifneq ($(REQUESTED_BUILDER_TARGETS),)
BUILDER_HOST := $(or $(EXPLICIT_HOST),$(HOST))
REMOTE_BUILDERS := $(shell bash misc/remote-builders.sh '$(BUILDER_HOST)')
BUILDERS_FLAG := $(if $(REMOTE_BUILDERS),--builders '$(REMOTE_BUILDERS)',--builders '')
REBUILD_BUILDERS := $(if $(REMOTE_BUILDERS),--builders '$(REMOTE_BUILDERS)',--builders '')
endif

# $$ so Make leaves command substitution and env vars for the shell.
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

syncthing-init:
	sudo nix run nixpkgs#syncthing -- generate --home=/var/lib/syncthing-hermes/.config/syncthing
	sudo chown -R hermes:hermes /var/lib/syncthing-hermes
	@printf '\n^^^ Device ID for $(HOST) is on the "Calculated device ID" line above — paste it into flake.nix hostDefs\n'

headless-env:
	bash misc/export-headless-env.sh

secrets-backup:
	@test -d "$$HOME/.secrets" || { echo 'secrets-backup: ~/.secrets does not exist'; exit 1; }
	@bash -o pipefail -c 'umask 077; tar --create --acls --xattrs --file=- -C "$$HOME" .secrets | openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -salt -out "$(SECRETS_ARCHIVE)"'
	@printf 'Encrypted secrets written to %s\n' "$(SECRETS_ARCHIVE)"

secrets-restore:
	@test -f "$(SECRETS_ARCHIVE)" || { echo 'secrets-restore: $(SECRETS_ARCHIVE) does not exist'; exit 1; }
	@bash -o pipefail -c 'openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -in "$(SECRETS_ARCHIVE)" | tar --extract --acls --xattrs --file=- -C "$$HOME"'
	@printf 'Secrets restored to %s\n' "$$HOME/.secrets"

$(HOSTS):
	$(if $(filter image deploy,$(MAKECMDGOALS)),@:,$(call nixos-rebuild,switch,$@))
