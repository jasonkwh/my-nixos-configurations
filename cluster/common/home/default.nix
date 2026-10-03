# Home Manager router. Host class comes from the flags in flake.nix.
#
#   every host                     -> cli.nix
#   !isHeadless                    -> apps.nix
#   !isHeadless && !isSteamMachine -> plasma.nix
#   isSteamMachine                 -> xmrig.nix, hermes.nix, syncthing.nix, steamos.nix
#   isLaptop && !isSteamMachine    -> laptop.nix
#
# Headless boards therefore get nothing display-dependent; adding a new
# machine never requires touching this file.
{
  lib,
  isLaptop ? false,
  isHeadless ? false,
  isSteamMachine ? false,
  ...
}:

{
  imports =
    [
      ./cli.nix
    ]
    ++ lib.optionals (!isHeadless) [
      ./apps.nix
    ]
    ++ lib.optionals (!isHeadless && !isSteamMachine) [
      ./plasma.nix
    ]
    ++ lib.optionals isSteamMachine [
      ./xmrig.nix
      ./hermes.nix
      ./syncthing.nix
      ./steamos.nix
    ]
    ++ lib.optionals (isLaptop && !isSteamMachine) [
      ./laptop.nix
    ];
}
