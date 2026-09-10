{
  description = "My NixOS Flake";

  nixConfig = {
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    hermes-agent.url = "github:NousResearch/hermes-agent/v2026.9.7";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs = { self, nixpkgs, home-manager, plasma-manager, nixos-hardware, ... }@inputs:
    let
      lib = nixpkgs.lib;
      username = "jasonkwh";
      fullName = "Jason Huang";
      email = "jasonkwh@gmail.com";
      homeDirectory = "/home/${username}";
      tailscaleDomain = "tail0c0276.ts.net";

      # Hermes model config — single source of truth; passed into
      # cluster/common/configuration.nix via specialArgs.
      hermesModel = {
        provider = "openrouter";
        default = "z-ai/glm-5.3-flash";
        base_url = "https://openrouter.ai/api/v1";
      };

      # Home Manager entry point shared verbatim by every host (and the Live
      # image). cluster/common/home.nix is a pure router: every host gets
      # home-headless core; isLaptop/isHeadless flags (set per-host below)
      # add home-desktop / home-laptop layers. Per-host extra packages live
      # in cluster/<host>/home.nix.
      homeManagerModule = { isLaptop ? false, isHeadless ? false }: {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.backupFileExtension = "backup";
        home-manager.extraSpecialArgs = {
          inherit username fullName email homeDirectory isLaptop isHeadless;
        };
        home-manager.sharedModules = lib.mkIf (!isHeadless) [
          plasma-manager.homeModules.plasma-manager
        ];
      };

      # Per-host arch so non-x86 boards can join the fleet.
      # Hardware layout comes from each host's directory in this repo,
      # never from /etc/nixos.
      # Host definitions shared between nixosConfigurations, the hermes
      # agent-to-agent peer list (bot_peers), and Syncthing device ids.
      # syncthingId is the machine's Syncthing device fingerprint
      # (`syncthing -device-id`); omit it for hosts that don't sync.
      # isBuilder gates who joins buildMachines (cluster/common/configuration.nix).
      # hostPublicKey is the machine's SSH host key (read ON-BOARD via
      # cat /etc/ssh/ssh_host_ed25519_key.pub — never ssh-keyscan); it pins
      # the key for root-initiated builder SSH (programs.ssh.knownHosts).
      # Omit it for hosts whose key hasn't been read yet.
      hostDefs = {
        "jasonkwh-7300u" = {
          name = "7300u";
          hostSystem = "x86_64-linux";
          isLaptop = true;
          isBuilder = true;
          buildSpeed = 2;
          maxBuildJobs = 2;
          syncthingId = "U5DJ45M-J37KSC4-6D5Y2KZ-ARKDIQ7-SAPGPD3-IVIUI6M-3NOIOGZ-I2X3QQV";
        };
        "jasonkwh-7520u" = {
          name = "7520u";
          hostSystem = "x86_64-linux";
          isLaptop = true;
          isBuilder = true;
          buildSpeed = 3;
          maxBuildJobs = 4;
          hostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIODXodoJLkTtxwWGkqXIWW2dC0BXN/uHgb7eABbczTEZ";
          syncthingId = "WGJTJ54-F66PGU2-RRUYEYV-DBUDMT7-YNCBJYI-6YKCJID-CJRD5GT-DUI6CQ5";
        };
        "jasonkwh-2450m" = {
          name = "2450m";
          hostSystem = "x86_64-linux";
          isLaptop = true;
          isBuilder = true;
          buildSpeed = 1;
          maxBuildJobs = 4;
          hostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG+KOrVNYK6dBw+Ucv53poZ2Ptszaav5ZpFA+j/5+FKP";
          syncthingId = "WGQMBDR-UDX7MWW-JMDKKSQ-PRSIE6H-WJXKGGU-PMPCZKA-JV6VJL6-C6YBSAN";
        };
        "jasonkwh-bcm2711" = {
          name = "bcm2711";
          hostSystem = "aarch64-linux";
          isHeadless = true;
          isFleetHub = true;
          isBuilder = true;
          buildSpeed = 3;
          maxBuildJobs = 2;
          extraModules = [ nixos-hardware.nixosModules.raspberry-pi-4 ];
          hostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMliakPvWur4Rh8cPKw83mEFGwfS/2OlsfO5g9p+BztM";
          syncthingId = "3HVJKXT-JBAOZME-7IO7IXE-ZVA3RPU-NVZ37PL-G26C3V7-JFAETLE-ZOFKBAB";
        };
        "jasonkwh-bcm2710a1" = {
          name = "bcm2710a1";
          hostSystem = "aarch64-linux";
          isHeadless = true;
          hostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJVmSSuzESOHYQnRrIqDVlh66vxID1pgQ08RV5u/MwBW";
          syncthingId = "GXTKLBM-LRAL3TP-KDWRB2S-PSWCIIY-5AL77HX-LIRAK2G-PL6HIPH-AXTVBQ5";
        };
        "jasonkwh-3210m" = {
          name = "3210m";
          hostSystem = "x86_64-linux";
          isLaptop = true;
          isBuilder = true;
          buildSpeed = 1;
          maxBuildJobs = 2;
          hostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJsR36gqTe9gKZ6y7STXvHaLbN/lDIJH9xD3c4akH4cN";
          syncthingId = "WOXKEDN-PWOAESC-GEULKND-C66M4IV-FPQTUWW-TL6554M-H2BSD2L-P2AF3QX";
        };
        "jasonkwh-1650v2" = {
          name = "1650v2";
          hostSystem = "x86_64-linux";
          isLaptop = false;
        };
      };

      # Lightweight metadata for Make's reachability probe. Reading this
      # output avoids evaluating an entire NixOS + Home Manager configuration
      # before nixos-rebuild performs the real evaluation.
      builderHosts = builtins.mapAttrs
        (targetHost: targetDef:
          builtins.map
            (host: "${host}.${tailscaleDomain}")
            (builtins.attrNames (lib.filterAttrs
              (host: def:
                def.isBuilder or false
                && host != targetHost
                && def.hostSystem == targetDef.hostSystem)
              hostDefs)))
        hostDefs;

      hermesPeerHosts = builtins.attrNames (lib.filterAttrs (_: def: def != null) hostDefs);

      mkHost = { name, isLaptop ? false, isHeadless ? false, isFleetHub ? false, hostSystem ? "x86_64-linux", extraModules ? [ ], hostName, ... }: nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit username fullName email homeDirectory isLaptop isHeadless tailscaleDomain;
          inherit isFleetHub;
          inherit name;
          inherit hermesPeerHosts;
          inherit hermesModel;
          inherit hostDefs;
          # Syncthing device ids for all fleet members that sync, from hostDefs.
          # Shaped as the `settings.devices` attrset ({ <name>.id = ...; }).
          syncthingDevices = builtins.mapAttrs
            (_: def: { id = def.syncthingId; })
            (lib.filterAttrs (_: def: def ? syncthingId) hostDefs);
          # Prefer the repo copy, fall back to /etc/nixos on first boot
          # (before nixos-generate-config output has been committed).
          hardwareConfig =
            if builtins.pathExists (./cluster/${name}/hardware-configuration.nix)
            then ./cluster/${name}/hardware-configuration.nix
            else /etc/nixos/hardware-configuration.nix;
        };
        modules = [
          { nixpkgs.hostPlatform = hostSystem; }
          inputs.hermes-agent.nixosModules.default
          # Hostname comes from the hostDefs key — single source of truth.
          { networking.hostName = lib.mkOverride 900 hostName; }
          ({ config, pkgs, ... }:
            lib.mkIf (isFleetHub && config.services.hermes-agent.enable) {
              services.hermes-agent.environment.WHATSAPP_ENABLED = "true";
              # The pypi wheel doesn't ship the top-level scripts/ dir, so the
              # WhatsApp bridge.js is missing from the nix package. Seed it into
              # HERMES_HOME from the pinned hermes-agent source; the adapter's
              # resolve_whatsapp_bridge_dir() picks up this copy when the
              # (read-only) install tree lacks it.
              systemd.services.hermes-agent.preStart = lib.mkAfter ''
                bridge_src="${inputs.hermes-agent}/scripts/whatsapp-bridge"
                bridge_dst="/var/lib/hermes/.hermes/scripts/whatsapp-bridge"
                if [ ! -f "$bridge_dst/bridge.js" ]; then
                  mkdir -p "$bridge_dst"
                  ${pkgs.coreutils}/bin/cp -r "$bridge_src"/. "$bridge_dst"/
                  chown -R hermes:hermes "$bridge_dst"
                fi
                # Store files are 0444; npm needs to write package-lock.json here.
                ${pkgs.coreutils}/bin/chmod -R u+w "$bridge_dst"
                chown -R hermes:hermes "$bridge_dst"
              '';
            })
          # Only x86 non-headless hosts get aarch64 QEMU emulation
          # (bcm2711 SD image builds). ARM/headless hosts never do.
          (lib.mkIf (hostSystem == "x86_64-linux" && !isHeadless) {
            boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
          })
          # ARM hosts cross-compile natively on x86 eval; on-board rebuilds
          # run --impure and see aarch64 currentSystem, so stay native.
          (lib.mkIf (hostSystem == "aarch64-linux" && (builtins.currentSystem or "x86_64-linux") == "x86_64-linux") {
            nixpkgs.hostPlatform = lib.mkDefault hostSystem;
            nixpkgs.buildPlatform = lib.mkDefault "x86_64-linux";
          })
          # tree-sitter cross-build: bindgen's clang needs the aarch64 target.
          (lib.mkIf (hostSystem == "aarch64-linux") {
            nixpkgs.overlays = [
              (final: prev: {
                tree-sitter = prev.tree-sitter.overrideAttrs (old: {
                  # rust-bindgen-hook overwrites BINDGEN_EXTRA_CLANG_ARGS in
                  # postHook, so re-append the target flag in preBuild.
                  preBuild = (old.preBuild or "") + lib.optionalString
                    (prev.stdenv.buildPlatform != prev.stdenv.hostPlatform) ''
                    export BINDGEN_EXTRA_CLANG_ARGS="$BINDGEN_EXTRA_CLANG_ARGS --target=${prev.stdenv.hostPlatform.config}"
                  '';
                });
                # neovim cross build: codegen lua (LUA_GEN_PRG) must load the
                # aarch64 libnlua0.so, so run aarch64 luajit under qemu
                # (upstream #38076, host-side nlua0 unsupported).
                neovim-unwrapped = prev.neovim-unwrapped.overrideAttrs (old:
                  lib.optionalAttrs
                    (prev.stdenv.buildPlatform != prev.stdenv.hostPlatform)
                    {
                      # wrapper script (created in preConfigure) so cmake gets
                      # a single executable path.
                      cmakeFlags = old.cmakeFlags ++ [
                        (lib.cmakeFeature "LUA_GEN_PRG" "/build/qemu-luajit")
                      ];
                      preConfigure = (old.preConfigure or "") + ''
                        printf '#!/bin/sh\nexec %s %s/bin/luajit "$@"\n' \
                          "${prev.stdenv.hostPlatform.emulator prev.buildPackages}" \
                          "${prev.luajit}" > /build/qemu-luajit
                        chmod +x /build/qemu-luajit
                      '';
                    });
              })
            ];
          })
        ] ++ extraModules ++ [
          ./cluster/${name}/configuration.nix
          # hermes: the service user runs builds/evals too (cron jobs,
          # agent tooling) and must be allowed to set substituters from
          # flake nixConfig — e.g. nix-community cachix.
          {
            nix.settings.trusted-users = [ username "hermes" ];
          }
          home-manager.nixosModules.home-manager
          (homeManagerModule { inherit isLaptop isHeadless; })
        ];
      };

    in
    {
      fleetBuilderHosts = builderHosts;

      nixosConfigurations = builtins.mapAttrs
        (hostName: def: mkHost (def // { inherit hostName; }))
        hostDefs;

    };
}
