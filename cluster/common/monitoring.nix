# Fleet monitoring: node_exporter everywhere; Prometheus/Grafana/Loki on the
# isFleetHub host. All traffic stays on the tailnet.
#
# Module body is lib.mkMerge, NOT attrset `//`: `//` shallow-replaces the
# `exporters` subtree and silently drops node exporter on the hub.
{ config, pkgs, lib, hostDefs, isFleetHub, tailscaleDomain, homeDirectory, monero, bitcoin, ... }:

let
  # Hub MagicDNS name from hostDefs (Grafana :3001, Alloy -> Loki :3100).
  fleetHubUrl = "${
    builtins.head (builtins.attrNames
      (lib.filterAttrs (_: d: d.isFleetHub or false) hostDefs))
  }.${tailscaleDomain}";

  # Hosts with xmrig.nix applied, i.e. everything not headless. xmrig is run
  # manually, so most of these will be down at any given time.
  xmrigHosts = builtins.attrNames
    (lib.filterAttrs (_: d: !(d.isHeadless or false)) hostDefs);
in
lib.mkMerge [
  {
    services.prometheus.exporters.node = {
      enable = true;
      listenAddress = "0.0.0.0";
      enabledCollectors = [ "systemd" "textfile" ];
      # Shared dir: hub writes openrouter.prom, hermes hosts write llm.prom.
      extraFlags = [ "--collector.textfile.directory=/var/lib/prometheus-textfile" ];
    };
    systemd.tmpfiles.rules = [
      "d /var/lib/prometheus-textfile 0755 hermes hermes"
    ];
  }

  {
    services.prometheus.exporters.blackbox = lib.mkIf isFleetHub {
      enable = true;
      listenAddress = "127.0.0.1";
      configFile = pkgs.writeText "blackbox.yml" (
        builtins.toJSON {
          # 200 alone isn't enough: /health stays 200 while disconnected —
          # also require status:"connected".
          modules.whatsapp_connected = {
            prober = "http";
            timeout = "5s";
            http = {
              preferred_ip_protocol = "ip4";
              valid_status_codes = [ 200 ];
              fail_if_body_not_matches_regexp = [ ''"status"\s*:\s*"connected"'' ];
            };
          };
        }
      );
    };

    # Exposes gateway /health JSON fields (queueLength, uptime) as gauges.
    services.prometheus.exporters.json = lib.mkIf isFleetHub {
      enable = true;
      listenAddress = "127.0.0.1";
      configFile = pkgs.writeText "json-exporter.yml" (
        builtins.toJSON {
          modules.whatsapp_gateway = {
            headers = { };
            metrics = [
              {
                # json_exporter v0.7.0 rejects type: gauge (upstream bug);
                # omit type, use k8s-style {.field} paths.
                name = "hermes_whatsapp_queue_length";
                path = "{.queueLength}";
                help = "WhatsApp gateway message queue backlog";
              }
              {
                name = "hermes_whatsapp_uptime_seconds";
                path = "{.uptime}";
                help = "WhatsApp gateway process uptime in seconds";
              }
            ];
          };

          # Bitaxe (AxeOS /api/system/info). Targets come from bitcoin.miners.
          modules.bitaxe = {
            metrics = [
              { name = "bitaxe_hashrate_1m"; path = "{.hashRate_1m}"; help = "Hashrate 1m avg (GH/s)"; }
              { name = "bitaxe_hashrate_10m"; path = "{.hashRate_10m}"; help = "Hashrate 10m avg (GH/s)"; }
              { name = "bitaxe_hashrate_1h"; path = "{.hashRate_1h}"; help = "Hashrate 1h avg (GH/s)"; }
              { name = "bitaxe_expected_hashrate"; path = "{.expectedHashrate}"; help = "Expected hashrate (GH/s)"; }
              { name = "bitaxe_temp"; path = "{.temp}"; help = "ASIC die temperature (C)"; }
              { name = "bitaxe_vr_temp"; path = "{.vrTemp}"; help = "VRM temperature (C)"; }
              { name = "bitaxe_power"; path = "{.power}"; help = "Power draw (W)"; }
              { name = "bitaxe_wifi_rssi"; path = "{.wifiRSSI}"; help = "WiFi RSSI (dBm)"; }
              { name = "bitaxe_error_percentage"; path = "{.errorPercentage}"; help = "Stale/reject error percentage"; }
              { name = "bitaxe_shares_accepted"; path = "{.sharesAccepted}"; help = "Shares accepted"; }
              { name = "bitaxe_shares_rejected"; path = "{.sharesRejected}"; help = "Shares rejected"; }
              { name = "bitaxe_best_diff"; path = "{.bestDiff}"; help = "Best share difficulty (lottery ticket)"; }
              { name = "bitaxe_best_session_diff"; path = "{.bestSessionDiff}"; help = "Best share difficulty this session"; }
              { name = "bitaxe_network_difficulty"; path = "{.networkDifficulty}"; help = "BTC network difficulty"; }
              { name = "bitaxe_pool_difficulty"; path = "{.poolDifficulty}"; help = "Pool share difficulty"; }
              { name = "bitaxe_uptime_seconds"; path = "{.uptimeSeconds}"; help = "Stratum session uptime (s)"; }
              { name = "bitaxe_total_uptime_seconds"; path = "{.totalUptimeSeconds}"; help = "Device lifetime uptime (s)"; }
              { name = "bitaxe_fan_rpm"; path = "{.fanrpm}"; help = "Fan speed (RPM)"; }
              { name = "bitaxe_frequency"; path = "{.actualFrequency}"; help = "Actual clock (MHz)"; }
              { name = "bitaxe_core_voltage"; path = "{.coreVoltageActual}"; help = "Actual ASIC core voltage (mV)"; }
              { name = "bitaxe_cpu_usage"; path = "{.cpuUsage}"; help = "ESP32 CPU usage (%)"; }
              { name = "bitaxe_free_heap"; path = "{.freeHeap}"; help = "Free heap (bytes)"; }
              { name = "bitaxe_block_height"; path = "{.blockHeight}"; help = "Current block height"; }
              { name = "bitaxe_response_time"; path = "{.responseTime}"; help = "Stratum response time (ms)"; }
              { name = "bitaxe_mining_paused"; path = "{.miningPaused}"; help = "1 = mining paused"; }
              { name = "bitaxe_overheat_mode"; path = "{.overheat_mode}"; help = "1 = thermal throttle active"; }
              { name = "bitaxe_small_core_count"; path = "{.smallCoreCount}"; help = "BM1370 small cores online"; }
              { name = "bitaxe_block_found"; path = "{.blockFound}"; help = "Blocks found"; }
              # NOT coinbaseValueUserSatoshis: it is the value of the coinbase
              # if a block were solved right now (3.125 BTC + fees), not winnings.
              # It drifts with every block while blockFound stays 0.
            ];
          };

          # XMRig /2/summary on the MoneroOcean miners (tailnet :16000).
          # hashrate.total windows are 10s, 60s, and 15m.
          # Array indexes are k8s-jsonpath, which json_exporter understands.
          modules.xmrig = {
            metrics = [
              { name = "xmrig_hashrate_10s"; path = "{.hashrate.total[0]}"; help = "Hashrate 10s avg (H/s)"; }
              { name = "xmrig_hashrate_1m"; path = "{.hashrate.total[1]}"; help = "Hashrate 1m avg (H/s)"; }
              { name = "xmrig_hashrate_15m"; path = "{.hashrate.total[2]}"; help = "Hashrate 15m avg (H/s)"; }
              { name = "xmrig_hashrate_highest"; path = "{.hashrate.highest}"; help = "Highest hashrate seen (H/s)"; }
              { name = "xmrig_shares_good"; path = "{.results.shares_good}"; help = "Good shares"; }
              { name = "xmrig_shares_total"; path = "{.results.shares_total}"; help = "Total shares"; }
              { name = "xmrig_diff_current"; path = "{.results.diff_current}"; help = "Current share difficulty"; }
              { name = "xmrig_best_diff"; path = "{.results.best[0]}"; help = "Best share difficulty (lottery ticket)"; }
              { name = "xmrig_avg_time"; path = "{.results.avg_time}"; help = "Avg seconds per share"; }
              { name = "xmrig_pool_ping"; path = "{.connection.ping}"; help = "Pool ping (ms)"; }
              { name = "xmrig_pool_failures"; path = "{.connection.failures}"; help = "Pool connection failures"; }
              { name = "xmrig_connection_uptime"; path = "{.connection.uptime}"; help = "Pool connection uptime (s)"; }
              { name = "xmrig_hashes_total"; path = "{.results.hashes_total}"; help = "Hashes since start"; }
              { name = "xmrig_uptime"; path = "{.uptime}"; help = "XMRig process uptime (s)"; }
              { name = "xmrig_paused"; path = "{.paused}"; help = "1 = miner paused"; }
              { name = "xmrig_load_average"; path = "{.resources.load_average[0]}"; help = "1m load average"; }
              { name = "xmrig_threads"; path = "{.cpu.threads}"; help = "Configured CPU threads"; }
            ];
          };
        }
      );
    };
  }

  {
    services.prometheus = lib.mkIf isFleetHub {
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
          # Hub's own /metrics already aggregates every peer.
          job_name = "syncthing";
          static_configs = [{ targets = [ "127.0.0.1:8384" ]; }];
        }
        {
          # Loopback /health; module already requires status:connected.
          job_name = "whatsapp-gateway";
          metrics_path = "/probe";
          params = { module = [ "whatsapp_connected" ]; };
          static_configs = [
            {
              targets = [ "127.0.0.1:3000/health" ];
            }
          ];
          relabel_configs = [
            { source_labels = [ "__address__" ]; target_label = "__param_target"; }
            { source_labels = [ "__param_target" ]; target_label = "instance"; }
            { target_label = "__address__"; replacement = "127.0.0.1:9115"; }
          ];
        }
        {
          # Same /health via json exporter for numeric fields (queue, uptime).
          job_name = "whatsapp-gateway-json";
          metrics_path = "/probe";
          params = { module = [ "whatsapp_gateway" ]; };
          static_configs = [
            { targets = [ "http://127.0.0.1:3000/health" ]; }
          ];
          relabel_configs = [
            { source_labels = [ "__address__" ]; target_label = "__param_target"; }
            { source_labels = [ "__param_target" ]; target_label = "instance"; }
            { target_label = "__address__"; replacement = "127.0.0.1:7979"; }
          ];
        }
        {
          # Bitaxe via AxeOS REST. Addresses come from bitcoin.miners in
          # flake.nix; they are static IPs set on the devices themselves.
          # instance is the device IP.
          job_name = "bitaxe";
          metrics_path = "/probe";
          params = { module = [ "bitaxe" ]; };
          static_configs = [
            {
              targets = map (m: "http://${m.ip_address}/api/system/info")
                bitcoin.miners;
            }
          ];
          relabel_configs = [
            { source_labels = [ "__address__" ]; target_label = "__param_target"; }
            {
              source_labels = [ "__param_target" ];
              regex = "http://([^/]+)/.*";
              target_label = "instance";
            }
            { target_label = "__address__"; replacement = "127.0.0.1:7979"; }
          ];
        }
        {
          # MoneroOcean miners exposing xmrig's HTTP API on the tailnet.
          # Targets follow hostDefs, not a hand-written list: xmrig.nix applies
          # to every non-headless host, so a new machine joins automatically.
          # xmrig runs manually, so down targets are expected, not a fault.
          # instance is the hostDefs hostname.
          job_name = "xmrig";
          metrics_path = "/probe";
          params = { module = [ "xmrig" ]; };
          static_configs = [
            {
              targets = map (host: "http://${host}.${tailscaleDomain}:16000/2/summary")
                xmrigHosts;
            }
          ];
          relabel_configs = [
            { source_labels = [ "__address__" ]; target_label = "__param_target"; }
            {
              source_labels = [ "__param_target" ];
              regex = "http://([^.]+)\\..*";
              target_label = "instance";
            }
            { target_label = "__address__"; replacement = "127.0.0.1:7979"; }
          ];
        }
      ];
    };

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 9100 ]
      ++ lib.optionals isFleetHub [ 3001 3100 ]; # Grafana :3001, Loki :3100

    services.grafana = lib.mkIf isFleetHub {
      enable = true;
      settings = {
        server = {
          http_addr = "0.0.0.0";
          http_port = 3001; # 3000 is the WhatsApp bridge
          domain = fleetHubUrl;
          root_url = "http://${fleetHubUrl}:3001/";
        };
        security = {
          admin_user = "jasonkwh";
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
        {
          name = "Loki";
          type = "loki";
          url = "http://127.0.0.1:3100";
        }
      ];
      provision.dashboards.settings.providers = [
        {
          name = "fleet";
          options.path = pkgs.symlinkJoin {
            name = "grafana-fleet-dashboards";
            paths = [
              (pkgs.writeTextDir "grafana-fleet-overview.json" (builtins.readFile ../../misc/grafana-fleet-overview.json))
              (pkgs.writeTextDir "grafana-syncthing.json" (builtins.readFile ../../misc/grafana-syncthing.json))
              (pkgs.writeTextDir "grafana-agent-status.json" (builtins.readFile ../../misc/grafana-agent-status.json))
              (pkgs.writeTextDir "grafana-logs.json" (builtins.readFile ../../misc/grafana-logs.json))
              (pkgs.writeTextDir "grafana-mining.json" (builtins.readFile ../../misc/grafana-mining.json))
            ];
          };
          options.foldersFromFilesStructure = false;
        }
      ];
    };

    # One-time random secret_key for the file provider above.
    systemd.services.grafana.preStart = lib.mkIf isFleetHub ''
      key=/var/lib/grafana/secret_key
      [ -s "$key" ] || ${pkgs.coreutils}/bin/head -c 32 /dev/urandom | ${pkgs.coreutils}/bin/base64 > "$key"
    '';
  }

  {
    services.prometheus.alertmanager = lib.mkIf isFleetHub {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 9093;
      extraFlags = [ "--cluster.listen-address=" ];
      configuration = {
        route = {
          receiver = "hermes-whatsapp";
          group_by = [ "..." ];
          group_wait = "0s";
          group_interval = "5m";
          repeat_interval = "4h";
          routes = [
            {
              matchers = [ ''alertname="HostDown"'' ];
              receiver = "hermes-whatsapp-once";
              repeat_interval = "8760h";
            }
            {
              matchers = [ ''alertname="BitaxeBlockFound"'' ];
              receiver = "hermes-whatsapp-once";
              repeat_interval = "8760h";
            }
            {
              matchers = [ ''severity="critical"'' ];
              repeat_interval = "1h";
            }
          ];
        };
        inhibit_rules = [
          {
            source_matchers = [ ''alertname="HermesAgentDown"'' ];
            target_matchers = [
              ''alertname="SystemdUnitFailed"''
              ''name="hermes-agent.service"''
            ];
            equal = [ "instance" ];
          }
          {
            source_matchers = [ ''alertname="HostDiskSpaceLow"'' ];
            target_matchers = [ ''alertname="HostDiskWillFillIn24Hours"'' ];
            equal = [ "instance" "mountpoint" ];
          }
        ];
        receivers = [
          {
            name = "hermes-whatsapp";
            webhook_configs = [
              {
                url = "http://127.0.0.1:8644/webhooks/alertmanager";
                send_resolved = true;
                timeout = "15s";
              }
            ];
          }
          {
            name = "hermes-whatsapp-once";
            webhook_configs = [
              {
                url = "http://127.0.0.1:8644/webhooks/alertmanager";
                send_resolved = false;
                timeout = "15s";
              }
            ];
          }
        ];
      };
    };

    services.prometheus.alertmanagers = lib.mkIf isFleetHub [
      {
        static_configs = [ { targets = [ "127.0.0.1:9093" ]; } ];
      }
    ];

    services.prometheus.ruleFiles = lib.mkIf isFleetHub [
      ../../misc/prometheus-fleet-rules.yml
    ];
  }

  # OpenRouter balance -> textfile. EnvironmentFile is read by systemd as
  # root; hermes has no ACL on ~/.secrets/hermes-env.
  {
    systemd.services.prometheus-openrouter-credits = lib.mkIf isFleetHub {
      description = "Poll OpenRouter credit balance into node_exporter textfile";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "hermes";
        EnvironmentFile = "${homeDirectory}/.secrets/hermes-env";
      };
      script = ''
        out=/var/lib/prometheus-textfile/openrouter.prom
        tmp=$out.tmp
        auth="Authorization: Bearer $OPENROUTER_API_KEY"
        json=$(${pkgs.curl}/bin/curl -sf --max-time 10 https://openrouter.ai/api/v1/credits -H "$auth") || exit 0
        balance=$(${pkgs.jq}/bin/jq -er '.data.total_credits - .data.total_usage' <<<"$json") || exit 0
        daily=
        keyjson=$(${pkgs.curl}/bin/curl -sf --max-time 10 https://openrouter.ai/api/v1/key -H "$auth") || keyjson=
        if [ -n "$keyjson" ]; then
          daily=$(${pkgs.jq}/bin/jq -er '.data.usage_daily | select(. != null)' <<<"$keyjson") || daily=
        fi
        {
          printf '%s\n' \
            '# HELP hermes_openrouter_credits_remaining OpenRouter balance (total_credits - total_usage)' \
            '# TYPE hermes_openrouter_credits_remaining gauge'
          ${pkgs.jq}/bin/jq -rn --argjson b "$balance" '"hermes_openrouter_credits_remaining \($b)"'
          if [ -n "$daily" ]; then
            printf '%s\n' \
              '# HELP hermes_openrouter_usage_daily OpenRouter API key spend today (UTC)' \
              '# TYPE hermes_openrouter_usage_daily gauge'
            ${pkgs.jq}/bin/jq -rn --argjson d "$daily" '"hermes_openrouter_usage_daily \($d)"'
          fi
        } > "$tmp"
        ${pkgs.coreutils}/bin/mv "$tmp" "$out"
      '';
    };
    systemd.timers.prometheus-openrouter-credits = lib.mkIf isFleetHub {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/10";
        AccuracySec = "10s";
        Persistent = true;
      };
    };
  }

  # MoneroOcean pool + wallet into textfile. The API has no network-hashrate
  # endpoint, so derive it: RandomX network hashrate = difficulty / 120
  # (cross-checked against minerstat's 730.21B -> 6.085 GH/s, ratio 1/120).
  {
    systemd.services.prometheus-moneroocean = lib.mkIf isFleetHub {
      description = "Poll MoneroOcean for network hashrate and wallet totals";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "hermes";
      };
      script = ''
        out=/var/lib/prometheus-textfile/moneroocean.prom
        tmp=$out.tmp
        base=https://api.moneroocean.stream
        jq=${pkgs.jq}/bin/jq
        net=$(${pkgs.curl}/bin/curl -sf --max-time 15 "$base/network/stats") || exit 0
        w=$(${pkgs.curl}/bin/curl -sf --max-time 15 \
          "$base/miner/${monero.wallet}/stats") || exit 0
        diff=$($jq -r '.["18081"].difficulty // empty' <<<"$net") || exit 0
        [ -n "$diff" ] || exit 0
        {
          printf '%s\n' \
            '# HELP moneroocean_network_hashrate XMR network hashrate derived from difficulty/120 (H/s)' \
            '# TYPE moneroocean_network_hashrate gauge' \
            '# HELP moneroocean_network_difficulty Current XMR network difficulty' \
            '# TYPE moneroocean_network_difficulty gauge'
          ${pkgs.gawk}/bin/awk -v d="$diff" 'BEGIN{
            printf "moneroocean_network_hashrate %.0f\n", d/120
            printf "moneroocean_network_difficulty %.0f\n", d
          }'
          printf '%s\n' \
            '# HELP moneroocean_wallet_hashrate Combined hashrate of this wallet across miners (H/s)' \
            '# TYPE moneroocean_wallet_hashrate gauge' \
            '# HELP moneroocean_wallet_valid_shares Valid shares submitted by this wallet' \
            '# TYPE moneroocean_wallet_valid_shares gauge' \
            '# HELP moneroocean_wallet_invalid_shares Invalid/stale shares from this wallet' \
            '# TYPE moneroocean_wallet_invalid_shares gauge' \
            '# HELP moneroocean_wallet_unpaid_xmr Balance awaiting payout (XMR, atomic units/1e12)' \
            '# TYPE moneroocean_wallet_unpaid_xmr gauge' \
            '# HELP moneroocean_wallet_paid_xmr Total already paid out (XMR, atomic units/1e12)' \
            '# TYPE moneroocean_wallet_paid_xmr gauge'
          # Wallet numbers stay inside jq. Bash defaults in this Nix string are
          # rewritten before the script runs, so jq would see the literal text.
          $jq -r '
            "moneroocean_wallet_hashrate \(.hash // 0)",
            "moneroocean_wallet_valid_shares \(.validShares // 0)",
            "moneroocean_wallet_invalid_shares \(.invalidShares // 0)",
            "moneroocean_wallet_paid_xmr \((.amtPaid // 0) / 1e12)",
            "moneroocean_wallet_unpaid_xmr \((.amtDue // 0) / 1e12)"
          ' <<<"$w"
        } > "$tmp"
        ${pkgs.coreutils}/bin/mv "$tmp" "$out"
      '';
    };
    systemd.timers.prometheus-moneroocean = lib.mkIf isFleetHub {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/2";
        AccuracySec = "15s";
        Persistent = true;
      };
    };
  }

  {
    services.loki = lib.mkIf isFleetHub {
      enable = true;
      configuration = {
        server = {
          http_listen_address = "0.0.0.0";
          http_listen_port = 3100;
          grpc_listen_address = "0.0.0.0";
        };
        auth_enabled = false;
        analytics.reporting_enabled = false;
        common = {
          replication_factor = 1;
          ring = {
            instance_addr = "127.0.0.1";
            kvstore.store = "inmemory";
          };
        };
        ingester = {
          wal.dir = "/var/lib/loki/wal";
          chunk_idle_period = "5m";
          chunk_retain_period = "30s";
        };
        schema_config.configs = [
          {
            from = "2018-01-01";
            store = "tsdb";
            object_store = "filesystem";
            schema = "v13";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }
        ];
        storage_config = {
          filesystem.directory = "/var/lib/loki/chunks";
          tsdb_shipper = {
            active_index_directory = "/var/lib/loki/tsdb-index";
            cache_location = "/var/lib/loki/tsdb-cache";
          };
        };
        # 14d like Prometheus; Loki Go durations reject "d".
        limits_config.retention_period = "336h"; # 336h == 14d
        compactor = {
          working_directory = "/var/lib/loki/compactor";
          retention_enabled = true;
          delete_request_store = "filesystem";
        };
      };
    };
  }

  # Journald -> hub Loki. Relabel host/unit/level before Alloy strips __journal_*.
  {
    services.alloy = {
      enable = true;
      configPath = "/etc/alloy/config.alloy";
    };
    environment.etc."alloy/config.alloy".text = ''
      loki.write "default" {
        endpoint { url = "http://${fleetHubUrl}:3100/loki/api/v1/push" }
      }
      loki.relabel "journal" {
        forward_to = []
        rule {
          source_labels = ["__journal__systemd_unit"]
          target_label  = "unit"
        }
        rule {
          source_labels = ["__journal__hostname"]
          target_label  = "host"
        }
        rule {
          source_labels = ["__journal_priority_keyword"]
          target_label  = "level"
        }
      }
      loki.source.journal "journal" {
        max_age       = "24h"
        labels        = { job = "systemd-journal" }
        relabel_rules = loki.relabel.journal.rules
        forward_to    = [loki.write.default.receiver]
      }
    '';
    # DynamicUser already gets systemd-journal; don't override the user.
  }

  # Daily LLM totals from agent.log rotations; hermes-only.
  {
    systemd.services.prometheus-hermes-llm-tokens = lib.mkIf config.services.hermes-agent.enable {
      description = "Sum today's hermes LLM API calls/tokens from agent.log into node_exporter textfile";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "hermes";
      };
      script = ''
        out=/var/lib/prometheus-textfile/llm.prom
        tmp=$out.tmp
        today=$(${pkgs.coreutils}/bin/date +%Y-%m-%d)
        files=
        for f in /var/lib/hermes/.hermes/logs/agent.log /var/lib/hermes/.hermes/logs/agent.log.1 /var/lib/hermes/.hermes/logs/agent.log.2 /var/lib/hermes/.hermes/logs/agent.log.3; do
          [ -r "$f" ] && files="$files $f"
        done
        if [ -z "$files" ]; then
          : > "$tmp"
        else
          # One awk over all rotations: per-file appends duplicate metric
          # names and node_exporter drops the whole textfile.
          ${pkgs.gawk}/bin/awk -v d="$today" '
            $1 == d && /agent.conversation_loop: API call/ && !/API call failed/ {
              seen++
              match($0, /model=[^ ]+/); m = (RSTART ? substr($0, RSTART+6, RLENGTH-6) : "")
              match($0, / in=[0-9]+/);  i = (RSTART ? substr($0, RSTART+4, RLENGTH-4) : "")
              match($0, / out=[0-9]+/); o = (RSTART ? substr($0, RSTART+5, RLENGTH-5) : "")
              if (m == "" || i == "" || o == "") { bad++; next }
              calls[m]++; ti[m] += i; to[m] += o
            }
            END {
              if (seen + bad == 0) exit
              printf "# HELP hermes_llm_tokens_lines_matched agent.log API-call lines seen today\n"
              printf "# TYPE hermes_llm_tokens_lines_matched gauge\n"
              printf "hermes_llm_tokens_lines_matched %d\n", seen+0
              printf "# HELP hermes_llm_tokens_parse_errors API-call lines with missing/renamed fields (nonzero = upstream log format changed)\n"
              printf "# TYPE hermes_llm_tokens_parse_errors gauge\n"
              printf "hermes_llm_tokens_parse_errors %d\n", bad+0
              if (length(calls) == 0) exit
              printf "# HELP hermes_llm_calls_total successful agent.log API calls today (resets midnight; gauge)\n"
              printf "# TYPE hermes_llm_calls_total gauge\n"
              printf "# HELP hermes_llm_tokens_in_total prompt tokens today (resets midnight; gauge)\n"
              printf "# TYPE hermes_llm_tokens_in_total gauge\n"
              printf "# HELP hermes_llm_tokens_out_total completion tokens today (resets midnight; gauge)\n"
              printf "# TYPE hermes_llm_tokens_out_total gauge\n"
              for (k in calls) {
                label = k; gsub(/[."\/]/, "_", label)
                printf "hermes_llm_calls_total{model=\"%s\"} %d\n", label, calls[k]
                printf "hermes_llm_tokens_in_total{model=\"%s\"} %d\n", label, ti[k]
                printf "hermes_llm_tokens_out_total{model=\"%s\"} %d\n", label, to[k]
              }
            }' $files > "$tmp"
        fi
        ${pkgs.coreutils}/bin/mv "$tmp" "$out"
      '';
    };
    systemd.timers.prometheus-hermes-llm-tokens = lib.mkIf config.services.hermes-agent.enable {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/10";
        AccuracySec = "10s";
        Persistent = true;
      };
    };
  }
]
