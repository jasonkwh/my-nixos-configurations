# Fleet monitoring: node_exporter everywhere; Prometheus/Grafana/Loki on the
# isFleetHub host. All traffic stays on the tailnet.
#
# Module body is lib.mkMerge, NOT attrset `//`: `//` shallow-replaces the
# `exporters` subtree and silently drops node exporter on the hub.
{ config, pkgs, lib, hostDefs, isFleetHub, tailscaleDomain, homeDirectory, ... }:

let
  # Hub MagicDNS name from hostDefs (Grafana :3001, Alloy -> Loki :3100).
  fleetHubUrl = "${
    builtins.head (builtins.attrNames
      (lib.filterAttrs (_: d: d.isFleetHub or false) hostDefs))
  }.${tailscaleDomain}";
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

  {
    services.loki = lib.mkIf isFleetHub {
      enable = true;
      configuration = {
        server = {
          http_listen_address = "0.0.0.0";
          http_listen_port = 3100;
          grpc_listen_address = "127.0.0.1";
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
        limits_config.retention_period = "336h";
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
