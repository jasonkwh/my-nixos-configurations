# Fleet monitoring: node_exporter everywhere; Prometheus + Grafana on the
# isFleetHub host. All traffic stays on the tailnet.
#
# NOTE: the module body is lib.mkMerge — do NOT switch to attrset `//`:
# a `//` between blocks would shallow-replace `exporters` and silently drop
# exporters.node on the server host (2026-09-10, bcm2711).
{ config, pkgs, lib, name, hostDefs, isFleetHub, tailscaleDomain, ... }:

lib.mkMerge [
  {
    services.prometheus.exporters.node = {
      enable = true;
      listenAddress = "0.0.0.0";
      enabledCollectors = [ "systemd" "textfile" ];
      # Single shared textfile dir: monitoring server writes openrouter.prom,
      # hermes hosts write llm.prom (see the units below).
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
          modules.http_2xx = {
            prober = "http";
            timeout = "5s";
            http = { preferred_ip_protocol = "ip4"; valid_status_codes = [ 200 ]; };
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
                name = "hermes_whatsapp_queue_length";
                path = "{{ .queueLength }}";
                type = "gauge";
                help = "WhatsApp gateway message queue backlog";
              }
              {
                name = "hermes_whatsapp_uptime_seconds";
                path = "{{ .uptime }}";
                type = "gauge";
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
          # Syncthing's own /metrics sees the whole fleet (folder states,
          # per-peer traffic); unauthenticated since the GUI has no password.
          job_name = "syncthing";
          static_configs = [{ targets = [ "127.0.0.1:8384" ]; }];
        }
        {
          # WhatsApp gateway health: blackbox HTTP probe of the bridge's
          # /health endpoint. probe_success carries the instance label, so
          # the dashboard always shows which host currently runs it.
          job_name = "whatsapp-gateway";
          metrics_path = "/probe";
          params = { module = [ "http_2xx" ]; };
          static_configs = [
            {
              # Gateway runs on this host (bcm2711) — probe via loopback.
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
          # Gateway /health JSON (queueLength, uptime) as numeric metrics.
          # Runs on the same host; json exporter polls loopback directly.
          job_name = "whatsapp-gateway-json";
          metrics_path = "/probe";
          params = { module = [ "whatsapp_gateway" ]; };
          static_configs = [
            { targets = [ "http://127.0.0.1:3000/health" ]; }
          ];
          relabel_configs = [
            { source_labels = [ "__address__" ]; target_label = "__param_url"; }
            { source_labels = [ "__param_url" ]; target_label = "instance"; }
            { target_label = "__address__"; replacement = "127.0.0.1:7979"; }
          ];
        }
      ];
    };

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 9100 ]
      ++ lib.optionals isFleetHub [ 3001 ];

    services.grafana = lib.mkIf isFleetHub {
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
          options.path = pkgs.symlinkJoin {
            name = "grafana-fleet-dashboards";
            paths = [
              (pkgs.writeTextDir "grafana-fleet-overview.json" (builtins.readFile ../../misc/grafana-fleet-overview.json))
              (pkgs.writeTextDir "grafana-syncthing.json" (builtins.readFile ../../misc/grafana-syncthing.json))
              (pkgs.writeTextDir "grafana-agent-status.json" (builtins.readFile ../../misc/grafana-agent-status.json))
            ];
          };
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

  # OpenRouter balance -> textfile; key only readable by hermes (server-only).
  {
    systemd.services.prometheus-openrouter-credits = lib.mkIf isFleetHub {
      description = "Poll OpenRouter credit balance into node_exporter textfile";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "hermes";
      };
      script = ''
        key=$(${pkgs.coreutils}/bin/grep -oP '^OPENROUTER_API_KEY=\K.*' /home/jasonkwh/.secrets/hermes-env)
        json=$(curl -sf --max-time 10 https://openrouter.ai/api/v1/credits -H "Authorization: Bearer $key") || exit 0
        balance=$(${pkgs.jq}/bin/jq -r '.data.total_credits - .data.total_usage' <<<"$json")
        ${pkgs.jq}/bin/jq -rn --argjson b "$balance" \
          '"# TYPE hermes_openrouter_credits_remaining gauge\n# HELP hermes_openrouter_credits_remaining OpenRouter balance (total_credits - total_usage)\nhermes_openrouter_credits_remaining \( $b )\n"' \
          > /var/lib/prometheus-textfile/openrouter.prom
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

  # Per-host LLM token usage from the hermes agent log, written to the shared
  # textfile dir. Daily totals: scans today's lines across log rotations and
  # resets at midnight. Gated on hermes being enabled on the host.
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
        : > "$tmp"
        today=$(${pkgs.coreutils}/bin/date +%Y-%m-%d)
        for f in /var/lib/hermes/.hermes/logs/agent.log /var/lib/hermes/.hermes/logs/agent.log.{1,2,3}; do
          [ -r "$f" ] || continue
          ${pkgs.gawk}/bin/awk -v d="$today" '
            $1 == d && /agent.conversation_loop: API call/ {
              match($0, /model=[^ ]+/);      m = substr($0, RSTART+6, RLENGTH-6)
              match($0, / in=[0-9]+/);       i = substr($0, RSTART+4, RLENGTH-4)
              match($0, / out=[0-9]+/);      o = substr($0, RSTART+5, RLENGTH-5)
              calls[m]++; ti[m] += i; to[m] += o
            }
            END {
              for (k in calls) {
                gsub(/[."\/]/, "_", k)
                printf "hermes_llm_calls_total{model=\"%s\"} %d\n", k, calls[k]
                printf "hermes_llm_tokens_in_total{model=\"%s\"} %d\n", k, ti[k]
                printf "hermes_llm_tokens_out_total{model=\"%s\"} %d\n", k, to[k]
              }
            }' "$f" >> "$tmp"
        done
        echo "# HELP hermes_llm_calls_total LLM API calls made today by hermes agent" >> "$tmp"
        echo "# TYPE hermes_llm_calls_total gauge" >> "$tmp"
        echo "# HELP hermes_llm_tokens_in_total LLM prompt tokens today (from agent.log API call lines)" >> "$tmp"
        echo "# TYPE hermes_llm_tokens_in_total gauge" >> "$tmp"
        echo "# HELP hermes_llm_tokens_out_total LLM completion tokens today" >> "$tmp"
        echo "# TYPE hermes_llm_tokens_out_total gauge" >> "$tmp"
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
