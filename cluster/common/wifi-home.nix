# Headless Wi-Fi bring-up from the fleet secrets file. NetworkManager creates
# its persistent connection at boot from ssid_home and psk_home, keeping both
# values out of the Nix store. Re-running this service refreshes the profile
# after replacing ~/.secrets/headless-env.
{
  pkgs,
  username,
  ...
}:

{
  systemd.services.wifi-home = {
    description = "Provision home Wi-Fi from headless-env";
    wantedBy = [ "network-online.target" ];
    before = [ "network-online.target" ];
    after = [ "NetworkManager.service" ];
    wants = [ "NetworkManager.service" ];
    path = [ pkgs.networkmanager ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      EnvironmentFile = "-/home/${username}/.secrets/headless-env";
    };
    script = ''
      if [ -z "''${ssid_home:-}" ] || [ -z "''${psk_home:-}" ]; then
        echo "wifi-home: no ssid_home/psk_home in headless-env; skipping"
        exit 0
      fi

      nmcli connection delete wifi-home >/dev/null 2>&1 || true
      nmcli connection add type wifi ifname wlan0 con-name wifi-home \
        ssid "$ssid_home"
      nmcli connection modify wifi-home \
        wifi-sec.key-mgmt wpa-psk \
        wifi-sec.psk "$psk_home" \
        connection.autoconnect yes
      nmcli connection up wifi-home
    '';
  };
}
