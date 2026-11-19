# Eclipse Mosquitto on the fleet hub. Imported only when isFleetHub is set.
# Clients reach it over Tailscale at <hub>.<tailnet>:1883. The tailnet is the
# allowlist: port 1883 is open only on tailscale0, and clients connect without
# a password. Any node on the tailnet can publish and subscribe.
#
# Each client publish is copied into Loki (job=mqtt, host=<this hub>, topic=...)
# for the ShengOS MQTT Grafana dashboard. $SYS is not included: a '#'
# subscription does not match topics that start with '$'.
{ config, lib, pkgs, isFleetHub, ... }:

let
  mqttPort = 1883;
  mqttPython = pkgs.python3.withPackages (ps: [ ps.paho-mqtt ]);

in
{
  assertions = [
    {
      assertion = isFleetHub;
      message = "mqtt.nix is the fleet-hub broker; import it only when isFleetHub is true";
    }
  ];

  environment.systemPackages = [ pkgs.mosquitto ];

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ mqttPort ];

  services.mosquitto = {
    enable = true;
    persistence = true;
    listeners = [
      {
        port = mqttPort;
        omitPasswordAuth = true;
        settings.allow_anonymous = true;
        # The ACL plugin denies everything when the file is empty.
        acl = [ "topic readwrite #" ];
      }
    ];
  };

  systemd.services.mqtt-to-loki = {
    description = "Copy MQTT publishes into Loki";
    after = [ "mosquitto.service" "loki.service" ];
    wants = [ "mosquitto.service" "loki.service" ];
    wantedBy = [ "multi-user.target" ];
    environment.MQTT_LOKI_HOST = config.networking.hostName;
    environment.MQTT_LOKI_PORT = toString mqttPort;
    serviceConfig = {
      Restart = "always";
      RestartSec = "2s";
    };
    script = ''
      exec ${mqttPython}/bin/python3 -u ${../../../misc/mqtt-to-loki.py}
    '';
  };
}
