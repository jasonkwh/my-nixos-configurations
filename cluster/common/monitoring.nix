# Fleet monitoring: node_exporter everywhere; Prometheus + Grafana on the
# isMonitoringServer host. All traffic stays on the tailnet.
{ config, pkgs, lib, name, hostDefs, isMonitoringServer, ... }:

{
  services.prometheus = {
    exporters.node = {
      enable = true;
      listenAddress = "0.0.0.0";
      enabledCollectors = [ "systemd" ];
    };
  } // lib.optionalAttrs isMonitoringServer {
    enable = true;
    retentionTime = "30d"; # SD-card friendly
    globalConfig.scrape_interval = "30s";

    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [
          {
            targets = map (host: "${host}.tail0c0276.ts.net:9100")
              (builtins.attrNames hostDefs);
          }
        ];
      }
      {
        # Syncthing's own /metrics sees the whole fleet (folder states,
        # per-peer traffic); unauthenticated since the GUI has no password.
        job_name = "syncthing";
        static_configs = [{ targets = [ "127.0.0.1:8384" ]; }];
      }
    ];
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 9100 ]
    ++ lib.optionals isMonitoringServer [ 3001 ];

  services.grafana = lib.mkIf isMonitoringServer {
    enable = true;
    settings = {
      server = {
        http_addr = "0.0.0.0";
        http_port = 3001; # 3000 is the WhatsApp bridge
        domain = "jasonkwh-${name}.tail0c0276.ts.net";
        root_url = "http://jasonkwh-${name}.tail0c0276.ts.net:3001/";
      };
      security.admin_user = "jasonkwh";
      analytics.reporting_enabled = false;
    };
    provision.datasources.settings.datasources = [
      {
        name = "Prometheus";
        type = "prometheus";
        url = "http://127.0.0.1:9090";
        isDefault = true;
      }
    ];
  };
}
