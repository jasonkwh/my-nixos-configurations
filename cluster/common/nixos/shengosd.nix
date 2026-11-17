{ lib, hostDefs, username, isHeadless ? false, isFleetHub ? false, ... }:

let
  fleetHub = lib.head (lib.attrNames (lib.filterAttrs (_: d: d.isFleetHub or false) hostDefs));
  # Clipboard needs a graphical session, so both settings follow one value.
  clipboard = !isHeadless;
in
{
  services.shengos-daemon = {
    enable = true;
    user = username;
    requireGraphicalSession = clipboard;
    environment = {
      CLIPBOARD_ENABLED = lib.boolToString clipboard;
      CLIPBOARD_SSHUSER = username;
      MQTTCONN_HOST = if isFleetHub then "localhost" else fleetHub;
    };
  };
}
