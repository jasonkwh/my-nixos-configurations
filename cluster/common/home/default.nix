# Home Manager router. Host class comes from the flags in flake.nix.
#
#   every host                     -> cli.nix
#   !isHeadless                    -> apps.nix, plasma.nix
#   isLaptop                       -> laptop.nix
#
# Headless boards therefore get nothing display-dependent; adding a new
# machine never requires touching this file.
{
  lib,
  isLaptop ? false,
  isHeadless ? false,
  ...
}:

{
  imports =
    [
      ./cli.nix
    ]
    ++ lib.optionals (!isHeadless) [
      ./apps.nix
      ./plasma.nix
    ]
    ++ lib.optionals isLaptop [
      ./laptop.nix
    ];
}
