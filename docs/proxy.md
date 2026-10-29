# Proxy entry node

One host in the fleet can act as a REALITY entry node, so a device abroad can
reach the internet (and the tailnet) through the home connection. It is off by
default: set `isProxyServer = true` on exactly one host in `flake.nix`, which
imports `cluster/common/nixos/proxy.nix`.

## What runs

A `sing-box` inbound of type `vless` with `flow: xtls-rprx-vision`, listening on
TCP `443` — the only port the module opens. REALITY mirrors the TLS handshake of
`www.microsoft.com`, so there is no certificate to obtain, no ACME loop, no
renewal, and no domain required for the node itself. The upstream site is chosen
because it speaks TLS 1.3 with X25519MLKEM768, has a clean chain, and is
reachable from an Australian residential line.

REALITY is not a transport of its own: to anything watching, the connection is a
plain visit to that site. When a client cannot prove it knows the REALITY
private key, sing-box forwards the connection to the real site, so probes learn
nothing.

## Credentials

The service reads three values, and nothing secret is in the nix store or this
repository:

| File                             | Purpose                             |
| -------------------------------- | ----------------------------------- |
| `~/.secrets/proxy-env/private-key` | REALITY X25519 private key (server) |
| `~/.secrets/proxy-env/public-key`  | same pair's public half (clients)   |
| `~/.secrets/proxy-env/uuid`        | VLESS user id                       |

Generate them once:

```bash
mkdir -p ~/.secrets/proxy-env && chmod 700 ~/.secrets/proxy-env
(umask 077; nix run nixpkgs#sing-box -- generate reality-keypair \
  | awk -F': ' '/^PrivateKey:/{print $2 > (ENVIRON["HOME"] "/.secrets/proxy-env/private-key")} /^PublicKey:/{print $2 > (ENVIRON["HOME"] "/.secrets/proxy-env/public-key")}')
(umask 077; nix run nixpkgs#sing-box -- generate uuid | tr -d '\n' > ~/.secrets/proxy-env/uuid)
```

`umask 077` keeps redirections from landing world-readable (default `644`);
`nix run` avoids needing sing-box installed. `make secrets-backup` archives the
whole directory, so the keys survive a reflash. Every fleet host that carries
the same secrets file can read the public key from there — the private key and
uuid are only useful to the node and to clients respectively, but they travel
together for convenience.

The module renders these files into `/run/sing-box/config.json` at start-up
(`ExecStartPre` runs as root), so the service keeps working with root-owned
secrets while the files stay `600`.

## Exposing it

The node needs a stable LAN address and one forwarded port:

1. In the eero app, reserve the node's Wi-Fi MAC to a fixed IPv4.
2. Forward TCP `443` to that address (one rule; no UDP needed for REALITY).

A residential IP is not a public exit: shared with many devices it gets blocked
quickly, so keep it to your own machines.

## Client side

Clients pin these four values, plus `flow: xtls-rprx-vision`. Anything
mismatched fails with no useful error — the client just times out or sees the
camouflage site.

| Value      | Where                                                   |
| ---------- | ------------------------------------------------------- |
| `uuid`     | `~/.secrets/proxy-env/uuid`                             |
| public key | `~/.secrets/proxy-env/public-key`                       |
| `short_id` | `proxy.nix` (`short_id`)                                |
| SNI        | `proxy.nix` (`sni`)                                     |

The compact form is a share link, which every common client imports:

```
vless://<uuid>@<node-ip>:443?security=reality&sni=www.microsoft.com&fp=chrome&pbk=<public-key>&sid=<short_id>&type=tcp&flow=xtls-rprx-vision#shengos
```

Clients: sing-box (Linux/NixOS, Android, iOS via Karing/Shadowrocket), v2rayN or
Hiddify on Windows, Hiddify/Karing on macOS.

Two client-side notes:

- Route DNS through the tunnel (`https://1.1.1.1/dns-query` with
  `detour: proxy`). Leaving DNS on the local resolver gives "connected but
  pages won't open", which looks exactly like a dead node.
- Prefer TUN mode over a system proxy; a system proxy is bypassed by Electron
  apps and desktop WeChat.

## Operating notes

- **The node's WAN address changes.** REALITY needs no domain, so clients simply
  use the current IP. To learn it from a blocked network, check the eero app or
  ask the hub. A DDNS record is optional and only helps if the hostname still
  resolves where the client is.
- **Missing secrets stop the service, not the system.** If
  `~/.secrets/proxy-env/*` is absent, `ExecStartPre` fails and
  `sing-box.service` does not start; create the files and switch again.
- **Port conflicts**: check `ss -tulnp | grep :443` before enabling on a host
  that already serves TLS.
- **Clock skew** breaks the handshake with a vague error; keep NTP healthy on
  both ends.
