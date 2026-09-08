<p align="center">
  <img src="assets/logos/logo.png" alt="ShengOS logo" width="180">
</p>

<h1 align="center">ShengOS</h1>

<p align="center">
  An AI-native, multi-device OS built on NixOS — declarative, monitored,
  and home to a resident AI companion.
</p>

<p align="center">
  <a href="docs/install.md"><b>📦 Installation Guide</b></a>
  ·
  <a href="#quick-start">Quick start</a>
  ·
  <a href="#machine-profiles">Machines</a>
  ·
  <a href="#command-reference">Command reference</a>
  ·
  <a href="#versioning">Versioning</a>
</p>

---

ShengOS is an AI-native, multi-device operating system built on
[NixOS](https://nixos.org/). Everything—applications, services, desktop
settings, security policy, and even the resident AI assistant's persona and
memory—is declared as code and reproduced across the fleet. The assistant can
operate the system, but only through a verified, owner-gated rebuild channel.

## Features

- **Declarative everything** — system, user, and desktop config live in this repo as code; `flake.lock` pins every dependency.
- **Fleet in lockstep** — Tailscale (networking) + Syncthing (file sync); hosts marked `isBuilder` share same-architecture builds over Tailscale SSH.
- **Controlled rebuild channel** — the `hermes` service user has no raw `nixos-rebuild`/`nix-env` sudo; it activates only store paths the owner verified via `shengos-switch`.
- **Fleet monitoring** — `node_exporter` on every host; the `isMonitoringServer` host runs Prometheus (30d retention) + Grafana (tailnet-only, port 3001).
- **Private assistant** — Hermes Agent with a personal companion (小升升); one designated host owns the WhatsApp gateway.
- **Headless boards** — SBCs run a stripped profile (no desktop/Steam/GPU stack, zram swap); SD images via `make image <host>`, Wi-Fi + Tailscale enrolment from `~/.secrets/headless-env`.
- **KDE Plasma** — curated desktop with theming, shortcuts, and Fcitx5 Chinese input.
- **Dev-ready** — containers (Podman), Kubernetes tooling, cloud CLIs, language runtimes.

## Machine profiles

ShengOS supports any number of machines sharing a common base, with
hardware-specific configuration scoped per-host. Both x86_64-linux and
aarch64-linux are supported:

| Profile | Hardware | Notes |
|---------|----------|-------|
| **`jasonkwh-7520u`** | AMD Ryzen 5 7520U · Radeon 610M · 16GB | Daily driver — Steam, gaming, hibernation |
| **`jasonkwh-7300u`** | Intel Core i5-7300U · HD Graphics 620 · 8GB | Spare laptop — hibernates to NVMe swap |
| **`jasonkwh-2450m`** | Intel Core i5-2450M · HD 3000 + Radeon HD 6630M · 16GB | Sony VAIO CB — legacy BIOS/MBR, retro gaming via PRIME offload |
| **`jasonkwh-1650v2`** | Intel Xeon E5-1650 v2 · FirePro D500 x2 · 64GB | Mac Pro 2013 (trashcan) — emulation/retro gaming + Tailscale node |
| **`jasonkwh-bcm2711`** | Broadcom BCM2711 · VideoCore VI · 4GB | Headless Hermes + WhatsApp gateway + monitoring server |
| **`jasonkwh-bcm2710a1`** | Broadcom BCM2710A1 · VideoCore IV · 512MB | Headless Syncthing backup node — Hermes disabled |

`mkHost` uses `hostSystem`, `isLaptop`, `isHeadless` to select system and
Home Manager layers; `isHermesWhatsappGateway` designates the single WhatsApp
gateway, `isMonitoringServer` the monitoring host (currently both
`jasonkwh-bcm2711`). x86 desktop hosts can build aarch64 SD images through
QEMU binfmt emulation. On the 512MB BCM2710A1, upgrades automatically stream
to BCM2711 for evaluation/build and copy back only the finished closure.

### Monitoring

Every host runs `node_exporter`, reachable only on `tailscale0` port 9100.
Prometheus scrapes all `hostDefs` targets via MagicDNS (30s interval);
Grafana is provisioned with a default Prometheus datasource — set the admin
password on first login at `http://jasonkwh-bcm2711.tail0c0276.ts.net:3001`.

## Quick start

`meow` wraps this repository's `Makefile` and works from any directory:

```bash
meow update          # nix flake update — refresh flake inputs
meow upgrade         # rebuild + activate the current host's config
```

See [Command reference](#command-reference) for the full list, or
[docs/install.md](docs/install.md) to install ShengOS on a new machine.

## Personal assistant (小升升)

ShengOS ships with a personal AI assistant — **小升升** — a private companion
that lives on the machine, answers to its owner, and looks after them day to
day. She runs from the flake on Hermes-enabled hosts; memories and skills stay
in sync via Tailscale and Syncthing. The assistant can operate the system but
cannot replace it unilaterally: system activation goes through the
owner-gated `shengos-switch` channel only.

## Command reference

| Command | Description |
|---------|-------------|
| `meow upgrade` | Rebuild + activate the current host |
| `meow boot` | Rebuild for next reboot (also cleans `/boot`) |
| `meow update` | Refresh flake inputs (`nix flake update`) |
| `meow gc` | Delete old generations + refresh bootloader |
| `meow image <hostname>` | Build an SD-card image, e.g. `meow image jasonkwh-bcm2711` → `result/*.img.zst` |
| `meow headless-env` | Export Wi-Fi credentials (+ optional Tailscale auth key) into `~/.secrets/headless-env` |
| `meow <hostname>` | Rebuild a specific host (e.g. `meow jasonkwh-7520u`) |
| `meow syncthing-init` | One-time Syncthing identity bootstrap; prints the device ID for `hostDefs` |

`upgrade` defaults to the machine's hostname; use `HOST=` or a host target to
select another configuration.

## Repository layout

```
flake.nix            # Entry point — inputs, hosts
misc/                # Non-module assets: SOUL.md, export-headless-env.sh,
                     # remote-builders.sh
cluster/             # Per-host & shared NixOS config
  common/            #   Shared across all machines (branding, fonts, services…)
                     #   headless.nix — imported when isHeadless = true
                     #   home.nix — HM entry point routing home-headless/-desktop/-laptop
  7520u/  7300u/  2450m/  1650v2/   # Per-host config
  bcm2711/  bcm2710a1/              # aarch64 headless hosts

docs/                # Guides (install, troubleshooting, …)
assets/              # Logos, wallpapers
version.yaml         # Current release version (auto-bumped by CI)
.github/workflows/   # CI — self-hosted deploy + auto versioning
```

## Versioning

The current release is tracked in `version.yaml`. On every push to `main`,
the **Bump Version** workflow bumps it (patch by default, or `minor`/`major`
via `workflow_dispatch`), commits the update, and tags the release as
`vX.Y.Z` (semver).
