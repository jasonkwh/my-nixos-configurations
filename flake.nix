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
    hermes-agent.url = "github:NousResearch/hermes-agent/v2026.8.18";
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

  outputs = { self, nixpkgs, home-manager, plasma-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      username = "jasonkwh";
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

      mkHost = { name, ... }: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit username homeDirectory;
        };
        modules = [
          inputs.hermes-agent.nixosModules.default
          ({
            nixpkgs.overlays = [ kernelOverlay ];
          })
          ./cluster/${name}/configuration.nix
          {
            nix.settings.trusted-users = [ username ];
          }
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.extraSpecialArgs = {
              inherit username homeDirectory;
            };
            home-manager.sharedModules = [
              plasma-manager.homeModules.plasma-manager
            ];
          }
        ];
      };

    in
    {
      nixosConfigurations = {
        "jasonkwh-7300u" = mkHost { name = "7300u"; };
        "jasonkwh-7520u" = mkHost { name = "7520u"; };
      };
    };
}
