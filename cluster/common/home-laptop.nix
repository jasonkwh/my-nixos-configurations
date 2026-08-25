# Laptop-only Home Manager configuration.
# Imported by common/home.nix only when the host is created with
# isLaptop = true in flake.nix.
{ config, lib, ... }:

{
  home.sessionVariables = {
    # Tell all Electron apps (Cursor, VSCode, etc.) to use the native Wayland
    # backend when running under a Wayland compositor, avoiding the XWayland
    # translation layer which adds CPU/GPU overhead and input latency.
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
  };

  # Shared by both laptops: never suspend/sleep on lid close (the machines
  # run docked or headless most of the time).
  home.file.".config/powermanagementprofilesrc".text = ''
    [AC]
    lidAction=0

    [Battery]
    lidAction=0

    [LowBattery]
    lidAction=0
  '';

  # Fastfetch settings fully replace the built-in defaults, but the modules
  # list itself merges across modules — appending here adds the laptop-only
  # battery entry after the base list declared in common/home.nix.
  programs.fastfetch.settings.modules = lib.mkAfter [ "battery" ];
}
