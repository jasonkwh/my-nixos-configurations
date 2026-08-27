# Single Home Manager entry point shared by every fleet host.
# Selects host-class layers by flags (set per-host in flake.nix mkHost):
#
#   every host          -> home-headless.nix   (CLI toolchain core)
#   !isHeadless         -> home-desktop.nix    (Plasma / GUI / secrets)
#   isLaptop            -> home-laptop.nix     (lid, Wayland env, battery)
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
      ./home-headless.nix
    ]
    ++ lib.optionals (!isHeadless) [
      ./home-desktop.nix
    ]
    ++ lib.optionals isLaptop [
      ./home-laptop.nix
    ];
}
