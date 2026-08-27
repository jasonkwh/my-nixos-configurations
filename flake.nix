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
    hermes-agent.url = "github:NousResearch/hermes-agent/v2026.8.19";
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

      # Home Manager module shared verbatim by every host (and the Live image).
      # Host-class file selection happens per-host in cluster/<host>/configuration.nix:
      # desktop/laptop -> ../common/home.nix (chains home-headless core; laptop
      # extras gated inside by isLaptop); headless -> ../common/home-headless.nix.
      homeManagerModule = { isLaptop ? false, isHeadless ? false }: {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.backupFileExtension = "backup";
        home-manager.extraSpecialArgs = {
          inherit username fullName email homeDirectory isLaptop isHeadless;
        };
        home-manager.sharedModules = [
          plasma-manager.homeModules.plasma-manager
        ];
      };

      # Per-host arch so non-x86 boards can join the fleet.
      # Hardware layout comes from each host's directory in this repo,
      # never from /etc/nixos.
      mkHost = { name, isLaptop ? false, isHeadless ? false, hostSystem ? "x86_64-linux", extraModules ? [ ] }: nixpkgs.lib.nixosSystem {
        system = hostSystem;
        specialArgs = {
          inherit username fullName email homeDirectory isLaptop isHeadless;
          # Each machine pulls its own cluster/<name>/hardware-configuration.nix,
          # imported in cluster/common/configuration.nix.
          hardwareConfig = ./cluster/${name}/hardware-configuration.nix;
        };
        modules = [
          inputs.hermes-agent.nixosModules.default
          ({ nixpkgs.overlays = [ kernelOverlay ]; })
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
      nixosConfigurations = {
        "jasonkwh-7300u" = mkHost { name = "7300u"; hostSystem = "x86_64-linux"; isLaptop = true; };
        "jasonkwh-7520u" = mkHost { name = "7520u"; hostSystem = "x86_64-linux"; isLaptop = true; };
        "jasonkwh-bcm2711" = mkHost {
          name = "bcm2711";
          isHeadless = true;
          hostSystem = "aarch64-linux";
          extraModules = [ nixos-hardware.nixosModules.raspberry-pi-4 ];
        };
        "jasonkwh-live" = liveUsb;
      };

      packages.x86_64-linux.shengos-live-iso = liveUsb.config.system.build.isoImage;
    };
}
