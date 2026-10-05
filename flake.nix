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
    hermes-agent.url = "github:NousResearch/hermes-agent/v2026.9.24";
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

      # XMRig / MoneroOcean mining — consumed by cluster/common/nixos/xmrig.nix.
      # 2xxxx ports are TLS; a 1xxxx port with tls = true will not connect.
      monero = {
        wallet = "88A5zQJj99VEtRUPCZ4jP3cNqKKam2Y25frhMVrNFUvdFQPhxpbJg4DB3qjZRxfjmhfneVm5KV1Jc8tVeHcZL76vNmKFPzk";
        pool.url = "gulf.moneroocean.stream:20004";
        pool.tls = true;
      };

      # SHA-256 miners — consumed by cluster/common/nixos/monitoring.nix. These run
      # AxeOS, not NixOS, and have no Tailscale, so they are reached by LAN IP
      # (the only non-MagicDNS target in the fleet). Set the address as a static
      # IP on the device; on DHCP the scrape target drifts and the job goes down.
      bitcoin.miners = [
        {
          name = "Bitaxe Gamma 601";
          ip_address = "192.168.4.20";
        }
      ];

      # Hermes model config — single source of truth; passed into
      # cluster/common/nixos via specialArgs.
      hermesModel = {
        provider = "openrouter";
        default = "deepseek/deepseek-v4.1-flash";
        base_url = "https://openrouter.ai/api/v1";
      };

      # Home Manager entry point shared verbatim by every host (and the Live
      # image). cluster/common/home is a pure router: every host gets
      # home/cli.nix; isLaptop/isHeadless flags (set per-host below)
      # add home/apps.nix, home/plasma.nix, and home/laptop.nix. Per-host extra packages live
      # in cluster/<host>/home.nix.
      homeManagerModule = { isLaptop ? false, isHeadless ? false, isSteamMachine ? false, hostName }: {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.backupFileExtension = "backup";
        home-manager.extraSpecialArgs = {
          inherit username fullName email homeDirectory isLaptop isHeadless isSteamMachine monero hostName;
        };
        home-manager.sharedModules = lib.mkIf (!isHeadless) [
          plasma-manager.homeModules.plasma-manager
        ];
      };

      # Fleet inventory. Hardware lives in cluster/<name>/, not /etc/nixos.
      # maxBuildJobs = min(cores, RAM_GB/4); Pi is 1 (hub services).
      # hostPublicKey: on-board ssh_host_ed25519_key.pub — never ssh-keyscan.
      hostDefs = {
        "jasonkwh-7300u" = {
          name = "7300u";
          hostSystem = "x86_64-linux";
          isLaptop = true;
          isBuilder = true;
          buildSpeed = 2;
          maxBuildJobs = 2;
          hostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKk5ItDGM2FVXZhn7c2B7u96cgximMG2fmlR6B+7nef1";
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
          maxBuildJobs = 2;
          hostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG+KOrVNYK6dBw+Ucv53poZ2Ptszaav5ZpFA+j/5+FKP";
          syncthingId = "WGQMBDR-UDX7MWW-JMDKKSQ-PRSIE6H-WJXKGGU-PMPCZKA-JV6VJL6-C6YBSAN";
        };
        "jasonkwh-bcm2711" = {
          name = "bcm2711";
          hostSystem = "aarch64-linux";
          isHeadless = true;
          isFleetHub = true;
          isBuilder = true;
          buildSpeed = 1;
          maxBuildJobs = 1;
          extraModules = [ nixos-hardware.nixosModules.raspberry-pi-4 ];
          hostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMliakPvWur4Rh8cPKw83mEFGwfS/2OlsfO5g9p+BztM";
          syncthingId = "3HVJKXT-JBAOZME-7IO7IXE-ZVA3RPU-NVZ37PL-G26C3V7-JFAETLE-ZOFKBAB";
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
        "jasonkwh-deck" = {
          name = "deck";
          hostSystem = "x86_64-linux";
          isSteamMachine = true;
          username = "deck";
          homeDirectory = "/home/deck";
        };
      };

      nixosHostDefs = lib.filterAttrs (_: def: !(def.isSteamMachine or false)) hostDefs;

      # Shaped as Syncthing's settings.devices ({ <name>.id = ...; }).
      # A host joins only after its syncthingId is set, so the Deck is absent
      # until make syncthing-init has printed one.
      syncthingDevices = builtins.mapAttrs
        (_: def: { id = def.syncthingId; })
        (lib.filterAttrs (_: def: def ? syncthingId) hostDefs);

      # NixOS peer list stays the pre-Deck fleet. The Deck dials these hosts;
      # adding it here would rewrite every NixOS Hermes config.
      hermesPeerHosts = builtins.attrNames nixosHostDefs;

      mkHost = { name, isLaptop ? false, isHeadless ? false, isFleetHub ? false, isSteamMachine ? false, hostSystem ? "x86_64-linux", extraModules ? [ ], hostName, ... }: nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit username fullName email homeDirectory isLaptop isHeadless isSteamMachine tailscaleDomain;
          inherit isFleetHub;
          inherit name;
          inherit hermesPeerHosts;
          inherit hermesModel;
          inherit hostDefs;
          inherit monero;
          inherit bitcoin;
          inherit syncthingDevices;
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
          (homeManagerModule { inherit isLaptop isHeadless isSteamMachine hostName; })
        ];
      };

      # SteamOS keeps its own system. Home Manager follows home.nix with
      # isSteamMachine, so the account lives on the hostDef, not here.
      mkSteamHome = hostName: def: home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = def.hostSystem;
          config.allowUnfree = true;
        };
        extraSpecialArgs = {
          inherit monero fullName email hermesModel hermesPeerHosts tailscaleDomain syncthingDevices;
          inherit (def) username homeDirectory;
          inherit hostName;
          isSteamMachine = true;
          isHeadless = false;
          isLaptop = false;
        };
        modules = [
          inputs.hermes-agent.homeManagerModules.default
          ./cluster/common/home
          ./cluster/${def.name}/home.nix
        ];
      };

    in
    {
      nixosConfigurations = builtins.mapAttrs
        (hostName: def: mkHost (def // { inherit hostName; }))
        nixosHostDefs;

      homeConfigurations = lib.mapAttrs mkSteamHome
        (lib.filterAttrs (_: def: def.isSteamMachine or false) hostDefs);

    };
}
