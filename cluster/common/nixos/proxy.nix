# REALITY entry node — VLESS + XTLS Vision. Imported only when a host sets
# isProxyServer = true in flake.nix. Credentials are rendered from
# ~/.secrets/proxy-env at start, so nothing secret lives in the store.
{ username, ... }:

let
  sni = "www.cloudflare.com";
  secretsDir = "/home/${username}/.secrets/proxy-env";
in
{
  services.sing-box = {
    enable = true;
    settings = {
      log = {
        level = "warn";
        timestamp = true;
      };

      inbounds = [
        {
          type = "vless";
          tag = "vless-reality";
          listen = "0.0.0.0";
          listen_port = 443;
          users = [
            {
              uuid = {
                _secret = "${secretsDir}/uuid";
              };
              flow = "xtls-rprx-vision";
            }
          ];
          tls = {
            enabled = true;
            server_name = sni;
            reality = {
              enabled = true;
              handshake = {
                server = sni;
                server_port = 443;
              };
              private_key = {
                _secret = "${secretsDir}/private-key";
              };
              short_id = [ "d8424154" ];
            };
          };
        }
      ];

      outbounds = [
        {
          type = "direct";
          tag = "direct";
        }
      ];
    };
  };

  networking.firewall.allowedTCPPorts = [ 443 ];
}
