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
    # Unstable channel, only for cherry-picking packages broken on the
    # stable pin (e.g. rpi-imager 2.0.9 + Qt 6.10, issue #1553).
    nixpkgs-master.url = "github:NixOS/nixpkgs/nixos-unstable";
    hermes-agent.url = "github:NousResearch/hermes-agent/v2026.8.27";
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

  outputs = { self, nixpkgs, nixpkgs-master, home-manager, plasma-manager, nixos-hardware, ... }@inputs:
    let
      lib = nixpkgs.lib;
      username = "jasonkwh";
      fullName = "Jason Huang";
      email = "jasonkwh@gmail.com";
      homeDirectory = "/home/${username}";

      # Hermes agent-to-agent peers: every NixOS host in the fleet gets a
      # bot_peers entry pointing at every other host (api_server on :8642).
      # Filled in inside the outputs attrset below, once nixosConfigurations
      # is available.

      kernelOverlay = final: prev: {
        linux_latest = prev.linux_latest.overrideAttrs (oldAttrs: {
          structuredExtraConfig = with prev.lib.kernelConfig; {
            NF_TABLES = module;
            NFT_COUNTER = module;
            NFT_EXPR_COUNTER = module;
            VXLAN = module;
            BRIDGE_NETFILTER = module;
          };
        });
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
          nixpkgs-master = inputs.nixpkgs-master;
        };
        home-manager.sharedModules = [
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
      # buildSpeed/maxBuildJobs feed the distributed buildMachines config in
      # cluster/common/configuration.nix; hosts without them are excluded.
      hostDefs = {
        "jasonkwh-7300u" = {
          name = "7300u";
          hostSystem = "x86_64-linux";
          isLaptop = true;
          buildSpeed = 2;
          maxBuildJobs = 4;
          syncthingId = "U5DJ45M-J37KSC4-6D5Y2KZ-ARKDIQ7-SAPGPD3-IVIUI6M-3NOIOGZ-I2X3QQV";
        };
        "jasonkwh-7520u" = {
          name = "7520u";
          hostSystem = "x86_64-linux";
          isLaptop = true;
          buildSpeed = 3;
          maxBuildJobs = 4;
          syncthingId = "WGJTJ54-F66PGU2-RRUYEYV-DBUDMT7-YNCBJYI-6YKCJID-CJRD5GT-DUI6CQ5";
        };
        "jasonkwh-bcm2711" = {
          name = "bcm2711";
          hostSystem = "aarch64-linux";
          isHeadless = true;
          extraModules = [ nixos-hardware.nixosModules.raspberry-pi-4 ];
          syncthingId = "PLACEHOLDER-REPLACE-WITH-REAL-DEVICE-ID-";
        };
        "jasonkwh-bcm2710a1" = {
          name = "bcm2710a1";
          hostSystem = "aarch64-linux";
          isHeadless = true;
          # No nixos-hardware module exists for Zero 2 W; generic aarch64.
          syncthingId = "PLACEHOLDER-REPLACE-WITH-REAL-DEVICE-ID-";
        };
        "jasonkwh-live" = null; # live USB: not a fleet peer, handled below
      };

      hermesPeerHosts = builtins.attrNames (lib.filterAttrs (_: def: def != null) hostDefs);

      mkHost = { name, isLaptop ? false, isHeadless ? false, hostSystem ? "x86_64-linux", extraModules ? [ ], hostName, ... }: nixpkgs.lib.nixosSystem {
        system = hostSystem;
        specialArgs = {
          inherit username fullName email homeDirectory isLaptop isHeadless;
          inherit hermesPeerHosts;
          inherit hostDefs;
          # Unstable channel for cherry-picking packages broken on the stable
          # pin (see cluster/7520u/configuration.nix rpi-imager).
          inherit (inputs) nixpkgs-master;
          # Syncthing device ids for all fleet members that sync, from hostDefs.
          # Shaped as the `settings.devices` attrset ({ <name>.id = ...; }).
          syncthingDevices = builtins.mapAttrs
            (_: def: { id = def.syncthingId; })
            (lib.filterAttrs (_: def: def ? syncthingId) hostDefs);
          # Each machine pulls its own cluster/<name>/hardware-configuration.nix,
          # imported in cluster/common/configuration.nix.
          hardwareConfig = ./cluster/${name}/hardware-configuration.nix;
        };
        modules = [
          inputs.hermes-agent.nixosModules.default
          ({ nixpkgs.overlays = [ kernelOverlay ]; })
          # Hostname comes from the hostDefs key — single source of truth.
          { networking.hostName = lib.mkOverride 900 hostName; }
          # Only x86 non-headless hosts get aarch64 QEMU emulation
          # (bcm2711 SD image builds). ARM/headless hosts never do.
          (lib.mkIf (hostSystem == "x86_64-linux" && !isHeadless) {
            boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
          })
        ] ++ extraModules ++ [
          ./cluster/${name}/configuration.nix
          {
            nix.settings.trusted-users = [ username ];
          }
          home-manager.nixosModules.home-manager
          (homeManagerModule { inherit isLaptop isHeadless; })
        ];
      };

      liveUsb = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit username fullName email homeDirectory;
          system = "x86_64-linux";
        };
        modules = [
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-graphical-calamares-plasma6.nix"
          ./cluster/live/configuration.nix
          {
            nix.settings.trusted-users = [ username ];
          }
          home-manager.nixosModules.home-manager
          (homeManagerModule { }) # live supports both laptop and desktop
        ];
      };

    in
    {
      nixosConfigurations = builtins.mapAttrs
        (hostName: def: if def == null then liveUsb else mkHost (def // { inherit hostName; }))
        hostDefs;

      packages.x86_64-linux.shengos-live-iso = liveUsb.config.system.build.isoImage;
    };
}
