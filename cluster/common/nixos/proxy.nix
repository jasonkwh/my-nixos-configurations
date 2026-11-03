# REALITY tunnel. Imported when a host sets isProxyServer or isProxyClient
# in flake.nix. Credentials are rendered from ~/.secrets/proxy-env at start,
# so nothing secret lives in the store. A host is one side or the other.
{ lib, pkgs, username, isProxyServer, isProxyClient, ... }:

let
  sni = "www.cloudflare.com";
  shortId = "d8424154";
  secretsDir = "/home/${username}/.secrets/proxy-env";
  secret = name: { _secret = "${secretsDir}/${name}"; };

  # Entry node: VLESS + XTLS Vision on 443, handing unknown probes to the
  # camouflage site.
  serverSettings = {
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
            uuid = secret "uuid";
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
            private_key = secret "private-key";
            short_id = [ shortId ];
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

  # Full tunnel. proxy-env/server is one address per line, no port: an IPv4
  # address, an IPv6 address, or a hostname. One line is dialed directly.
  # Several lines are probed, and the one this network can reach is used.
  clientSettings = {
    log = {
      level = "warn";
      timestamp = true;
    };

    dns = {
      servers = [
        # System resolver, used only to look up the entry node itself.
        {
          type = "local";
          tag = "local";
        }
        # Application DNS goes through the tunnel. An IP here avoids a
        # lookup before the tunnel exists.
        {
          type = "https";
          tag = "cloudflare";
          server = "1.1.1.1";
          path = "/dns-query";
          detour = "proxy";
        }
      ];
      final = "cloudflare";
      strategy = "prefer_ipv4";
    };

    inbounds = [
      {
        type = "tun";
        tag = "tun-in";
        interface_name = "singtun";
        address = [
          "172.19.0.1/30"
          "fdfe:dcba:9876::1/126"
        ];
        auto_route = true;
        auto_redirect = true;
        strict_route = true;
        # Current LAN stays local. Tailscale CGNAT is not excluded, so
        # 100.64.0.0/10 is dialed by the home node.
        route_exclude_address = [
          "10.0.0.0/8"
          "172.16.0.0/12"
          "192.168.0.0/16"
          "169.254.0.0/16"
          "fc00::/7"
          "fe80::/10"
        ];
      }
    ];

    outbounds = [
      {
        type = "vless";
        tag = "proxy";
        server = secret "server";
        server_port = 443;
        uuid = secret "uuid";
        flow = "xtls-rprx-vision";
        # A hostname in proxy-env/server is resolved before the tunnel is up.
        domain_resolver = "local";
        tls = {
          enabled = true;
          server_name = sni;
          utls = {
            enabled = true;
            fingerprint = "chrome";
          };
          reality = {
            enabled = true;
            public_key = secret "public-key";
            short_id = shortId;
          };
        };
      }
      {
        type = "direct";
        tag = "direct";
      }
    ];

    route = {
      # Bind the dial to the default NIC so the tunnel does not capture itself.
      auto_detect_interface = true;
      default_domain_resolver = "local";
      final = "proxy";
      rules = [
        { action = "sniff"; }
        {
          protocol = "dns";
          action = "hijack-dns";
        }
      ];
    };
  };

  # Runs after the module substitutes _secret values. A multi-line server
  # file becomes one VLESS outbound per line, grouped by urltest under the
  # tag the route and DNS detour already use.
  clientServers = pkgs.writeShellScript "sing-box-client-servers" ''
    set -eu
    cfg=/run/sing-box/config.json
    file=${lib.escapeShellArg "${secretsDir}/server"}
    ordered=$(${pkgs.gawk}/bin/awk '
      {
        gsub(/[[:space:]]/, "")
        sub(/^\[/, "")
        sub(/\]$/, "")
      }
      /^#/ || $0 == "" { next }
      /:/ { v6[nv6++] = $0; next }
      { v4[nv4++] = $0 }
      END {
        for (i = 0; i < nv4; i++) print v4[i]
        for (i = 0; i < nv6; i++) print v6[i]
      }
    ' "$file")
    if [ -z "$ordered" ]; then
      echo "proxy-env/server contains no address" >&2
      exit 1
    fi
    echo "sing-box proxy servers:" >&2
    printf '%s\n' "$ordered" >&2
    addrs_json=$(printf '%s\n' "$ordered" | ${pkgs.jq}/bin/jq -R . | ${pkgs.jq}/bin/jq -s .)
    count=$(printf '%s\n' "$ordered" | ${pkgs.gnugrep}/bin/grep -c .)
    if [ "$count" -eq 1 ]; then
      ${pkgs.jq}/bin/jq --argjson addrs "$addrs_json" '
        (.outbounds[] | select(.type == "vless" and .tag == "proxy").server) = $addrs[0]
      ' "$cfg" > "$cfg.tmp"
    else
      ${pkgs.jq}/bin/jq --argjson addrs "$addrs_json" '
        . as $root
        | ($root.outbounds[] | select(.type == "vless" and .tag == "proxy")) as $base
        | $root
        | .outbounds =
            ( [ range(0; $addrs | length) as $i
                | $base + { tag: ("proxy-" + ($i | tostring)), server: $addrs[$i] }
              ]
              + [ {
                  type: "urltest",
                  tag: "proxy",
                  outbounds: [ range(0; $addrs | length) | "proxy-" + tostring ],
                  url: "https://www.gstatic.com/generate_204",
                  interval: "3m",
                  tolerance: 50,
                  idle_timeout: "30m",
                  interrupt_exist_connections: true
                } ]
              + [ $root.outbounds[] | select(.tag != "proxy") ]
            )
      ' "$cfg" > "$cfg.tmp"
    fi
    ${pkgs.coreutils}/bin/mv "$cfg.tmp" "$cfg"
    ${pkgs.coreutils}/bin/chown --reference=/run/sing-box "$cfg"
    ${pkgs.coreutils}/bin/chmod 600 "$cfg"
  '';
in
{
  assertions = [
    {
      assertion = isProxyServer || isProxyClient;
      message = "proxy.nix requires isProxyServer or isProxyClient";
    }
    {
      assertion = !(isProxyServer && isProxyClient);
      message = "isProxyServer and isProxyClient cannot both be set on the same host";
    }
  ];

  boot = {
    kernelModules = lib.mkMerge [
      # Long-haul tunnel: the entry node is the sending side of the download direction.
      (lib.mkIf isProxyServer [ "tcp_bbr" ])
      # auto_redirect pre-matching uses nfqueue.
      (lib.mkIf isProxyClient [ "nfnetlink_queue" ])
    ];

    kernel.sysctl = lib.mkIf isProxyServer {
      "net.ipv4.tcp_congestion_control" = "bbr";
      "net.core.default_qdisc" = "fq";
    };
  };

  services.sing-box = {
    enable = true;
    settings = if isProxyServer then serverSettings else clientSettings;
  };

  # After _secret substitution, so a multi-line server file can be expanded.
  systemd.services.sing-box.serviceConfig.ExecStartPre = lib.mkIf isProxyClient (lib.mkAfter [
    "+${clientServers}"
  ]);

  networking.firewall.allowedTCPPorts = lib.mkIf isProxyServer [ 443 ];

  # TUN replies fail a strict reverse-path check.
  networking.firewall.checkReversePath = lib.mkIf isProxyClient "loose";
}
