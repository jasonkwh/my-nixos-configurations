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
  mqttPython = pkgs.python3.withPackages (ps: [ ps.paho-mqtt ]);
  mqttToLoki = pkgs.writeText "mqtt-to-loki.py" ''
  import json
  import os
  import sys
  import time
  import urllib.error
  import urllib.request

  import paho.mqtt.client as mqtt

  host = os.environ["MQTT_LOKI_HOST"]
  url = "http://127.0.0.1:3100/loki/api/v1/push"

  def push(topic, payload):
      body = json.dumps({
          "streams": [{
              "stream": {"job": "mqtt", "host": host, "topic": topic},
              "values": [[str(time.time_ns()), payload]],
          }]
      }).encode()
      req = urllib.request.Request(
          url, data=body, headers={"Content-Type": "application/json"}
      )
      delay = 1
      while True:
          try:
              with urllib.request.urlopen(req, timeout=5) as resp:
                  resp.read()
              return
          except (urllib.error.URLError, TimeoutError, OSError) as exc:
              print(f"loki push failed: {exc}", file=sys.stderr)
              if delay > 30:
                  raise SystemExit(1)
              time.sleep(delay)
              delay = min(delay * 2, 30)

  def on_connect(client, _userdata, _flags, reason_code, _properties):
      if getattr(reason_code, "is_failure", reason_code != 0):
          print(f"mqtt connect failed: {reason_code}", file=sys.stderr)
          return
      client.subscribe("#", qos=0)

  def on_message(_client, _userdata, message):
      push(message.topic, message.payload.decode("utf-8", errors="replace"))

  client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
  client.on_connect = on_connect
  client.on_message = on_message
  while True:
      try:
          client.connect("127.0.0.1", 1883, keepalive=60)
          client.loop_forever(retry_first_connection=True)
      except Exception as exc:
          print(f"mqtt connection failed: {exc}", file=sys.stderr)
          time.sleep(2)
  '';
in
{
  assertions = [
    {
      assertion = isFleetHub;
      message = "mqtt.nix is the fleet-hub broker; import it only when isFleetHub is true";
    }
  ];

  environment.systemPackages = [ pkgs.mosquitto ];

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 1883 ];

  services.mosquitto = {
    enable = true;
    persistence = true;
    listeners = [
      {
        port = 1883;
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
    serviceConfig = {
      Restart = "always";
      RestartSec = "2s";
    };
    script = ''
      exec ${mqttPython}/bin/python3 -u ${mqttToLoki}
    '';
  };
}
