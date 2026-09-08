# Fleet monitoring: node_exporter everywhere, Prometheus + Grafana on the
# monitoring server (jasonkwh-bcm2711, flagged isMonitoringServer in flake.nix).
# All traffic stays inside the tailnet; scrape targets use MagicDNS names.
{ config, pkgs, lib, name, hostDefs, isMonitoringServer, ... }:

{
  services.prometheus = {
    # Fleet-wide node metrics exporter (includes the monitoring server itself).
    exporters.node = {
      enable = true;
      listenAddress = "0.0.0.0";
      enabledCollectors = [ "systemd" ];
    };
  } // lib.optionalAttrs isMonitoringServer {
    enable = true;
    retentionTime = "30d";
    globalConfig.scrape_interval = "30s";

    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [
          {
            # Every fleet member with node_exporter (incl. this host).
            targets = map (host: "${host}.tail0c0276.ts.net:9100")
              (builtins.attrNames hostDefs);
          }
        ];
      }
    ];
  };

  # Exporter + (on the server) Grafana UI: tailscale0 only.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 9100 ]
    ++ lib.optionals isMonitoringServer [ 3001 ];

  services.grafana = lib.mkIf isMonitoringServer {
    enable = true;
    settings = {
      server = {
        http_addr = "0.0.0.0";
        # 3000 is taken by the WhatsApp bridge on bcm2711.
        http_port = 3001;
        # MagicDNS hostnames carry the jasonkwh- prefix; `name` is the short name.
        domain = "jasonkwh-${name}.tail0c0276.ts.net";
        root_url = "http://jasonkwh-${name}.tail0c0276.ts.net:3001/";
      };
      security = {
        admin_user = "jasonkwh";
        # Set the real admin password on first login, not in the repo.
        admin_password = "";
      };
      analytics.reporting_enabled = false;
    };
    provision.datasources.settings.datasources = [
      {
        name = "Prometheus";
        type = "prometheus";
        # Same-host scrape, direct port.
        url = "http://127.0.0.1:9090";
        isDefault = true;
      }
    ];
  };
}
