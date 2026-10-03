# NixOS Plasma session. SteamOS already runs Desktop Mode, so
# isSteamMachine hosts do not import this.
{ config, ... }:

{
  programs.plasma = {
    enable = true;

    workspace = {
      wallpaper = "${config.home.homeDirectory}/Documents/my-nixos-configurations/assets/wallpapers/DSCF4098.JPG";
      lookAndFeel = "org.kde.breezedark.desktop";
      colorScheme = "BreezeDark";
    };

    # Required for Fcitx5's native Wayland input-method frontend.
    configFile."kwinrc"."Wayland" = {
      InputMethod = {
        shellExpand = true;
        value = "/run/current-system/sw/share/applications/fcitx5-wayland-launcher.desktop";
      };
      VirtualKeyboardEnabled = true;
    };

    # Declared bottom panel, mirroring the existing 7520u layout; only
    # difference is pinning dolphin explicitly instead of preferred://filemanager.
    panels = [
      {
        screen = 0;
        location = "bottom";
        height = 44;
        alignment = "center";
        hiding = "none";
        floating = true;
        lengthMode = "fill";
        widgets = [
          {
            name = "org.kde.plasma.kickoff";
            config = {
              "General".systemFavorites = "suspend\\,hibernate\\,reboot\\,shutdown";
            };
          }
          {
            name = "org.kde.plasma.pager";
          }
          {
            name = "org.kde.plasma.icontasks";
            config = {
              "General".launchers =
                "applications:brave-browser.desktop,applications:org.kde.dolphin.desktop,applications:org.kde.konsole.desktop";
            };
          }
          {
            name = "org.kde.plasma.marginsseparator";
          }
          {
            name = "org.kde.plasma.systemtray";
          }
          {
            name = "org.kde.plasma.digitalclock";
            config = {
              "Appearance".fontWeight = 400;
            };
          }
          {
            name = "org.kde.plasma.showdesktop";
          }
        ];
      }
    ];

    # Baloo spins at ~40% CPU indexing dev workspaces.
    configFile."baloofilerc"."Basic Settings"."Indexing-Enabled" = false;
  };
}
