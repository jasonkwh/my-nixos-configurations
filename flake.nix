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
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";

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
        modules = [
          ({
            nixpkgs.overlays = [ kernelOverlay ];
          })
          ./cluster/${name}/configuration.nix
          {
            nix.settings.trusted-users = [ "jasonkwh" ];
          }
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
          }
        ];
      };
    in
    {
      nixosConfigurations = {
        "jasonkwh-7300u" = mkHost { name = "7300u"; };
        "jasonkwh-7520u" = mkHost { name = "7520u"; };
      };

      # Standalone Home Manager configuration for non-NixOS systems (e.g., Steam Deck distrobox)
      homeConfigurations = {
        "jasonkwh-steamdeck" = home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          modules = [
            ./cluster/steamdeck/home.nix
          ];
        };
      };
    };
}
