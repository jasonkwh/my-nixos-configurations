# Headless Wi-Fi bring-up from the fleet secrets file.
#
# The image is cross-built on the x86 laptops (make image ...). This module
# wires networking.wireless to a secretsFile holding the build host's current
# Wi-Fi credentials, written by cluster/common/export-headless-env.sh into
# ~/.secrets/headless-env (keys: ssid_home / psk_home). The PSK therefore
# never enters the flake, git, or the image — the board reads it at runtime
# like every other fleet secret. First boot on the home Wi-Fi needs no
# interaction.
#
# Refresh path: after changing the home Wi-Fi password, re-run
# export-headless-env.sh on a laptop, rsync ~/.secrets to the board, rebuild.
{
  config,
  lib,
  pkgs,
  username,
  ...
}:

{
  networking.wireless = {
    enable = true;
    # Secrets (psk_home) come from the env-style secrets file, never from
    # this flake. The file holds:  ssid_home=...  psk_home=...
    secretsFile = "/home/${username}/.secrets/headless-env";
    networks = {
      # The SSID itself is also a secret (ssid_home) so the home network name
      # stays out of git; wpa_supplicant ext: works for any field.
      "@ssid_home@" = {
        # 2.4GHz band — Zero 2 W / Pi 4B radios are 2.4GHz-only anyway.
        pskRaw = "ext:psk_home";
      };
    };
  };
}
