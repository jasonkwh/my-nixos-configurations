# Fleet monitoring: node_exporter everywhere; Prometheus + Grafana on the
# isMonitoringServer host. All traffic stays on the tailnet.
{ config, pkgs, lib, name, hostDefs, isMonitoringServer, tailscaleDomain, ... }:

{
  services.prometheus = {
    exporters.node = {
      enable = true;
      listenAddress = "0.0.0.0";
      enabledCollectors = [ "systemd" ];
    };
  } // lib.optionalAttrs isMonitoringServer {
    enable = true;
    retentionTime = "14d"; # Pi host — 30d wrote too much to SD for little value
    globalConfig.scrape_interval = "30s";

    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [
          {
            targets = map (host: "${host}.${tailscaleDomain}:9100")
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
        domain = "jasonkwh-${name}.${tailscaleDomain}";
        root_url = "http://jasonkwh-${name}.${tailscaleDomain}:3001/";
      };
      security = {
        admin_user = "jasonkwh";
        # Random per-host key, generated once by the preStart below.
        secret_key = "$__file{/var/lib/grafana/secret_key}";
      };
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
    provision.dashboards.settings.providers = [
      {
        name = "fleet";
        options.path = ../../misc/grafana-fleet-overview.json;
        options.foldersFromFilesStructure = false;
      }
      {
        name = "fleet";
        options.path = ../../misc/grafana-syncthing.json;
        options.foldersFromFilesStructure = false;
      }
    ];
  };

  # One-time random secret_key for the file provider above.
  systemd.services.grafana.preStart = ''
    key=/var/lib/grafana/secret_key
    [ -s "$key" ] || ${pkgs.coreutils}/bin/head -c 32 /dev/urandom | ${pkgs.coreutils}/bin/base64 > "$key"
  '';
}
