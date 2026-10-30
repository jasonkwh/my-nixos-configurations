# REALITY entry node — VLESS + XTLS Vision. Imported only when a host sets
# isProxyServer = true in flake.nix. Credentials are rendered from
# ~/.secrets/proxy-env at start, so nothing secret lives in the store.
{ username, ... }:

let
  sni = "www.cloudflare.com";
  secretsDir = "/home/${username}/.secrets/proxy-env";
in
{
  # Long-haul tunnel: this host is the sending side of the download direction.
  boot = {
    kernelModules = [ "tcp_bbr" ];
    
    kernel = {
      sysctl = {
        "net.ipv4.tcp_congestion_control" = "bbr";
        "net.core.default_qdisc" = "fq";
      };
    };
  };

  services.sing-box = {
    enable = true;
    settings = {
      log = {
        level = "warn";
        timestamp = true;
      };

      # Read-only stats for the textfile exporter. Loopback only, no auth.
      experimental.clash_api.external_controller = "127.0.0.1:9091";

      inbounds = [
        {
          type = "vless";
          tag = "vless-reality";
          listen = "::";
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
