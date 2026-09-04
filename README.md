<p align="center">
  <img src="assets/logos/logo.png" alt="ShengOS logo" width="180">
</p>

<h1 align="center">ShengOS</h1>

<p align="center">
  My personal, reproducible Linux environment built on NixOS.
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

ShengOS is a personal, reproducible Linux environment built on [NixOS](https://nixos.org/).
The system—including applications, services, desktop settings, and security
policy—is declared as code and can be reproduced or rolled back safely.

## Features

- **Declarative everything** — system, user, and desktop config all live in this repo as code.
- **Reproducible builds** — `flake.lock` pins every dependency; switch machines freely.
- **Distributed builds** — hosts marked `isBuilder` share same-architecture
  builds over Tailscale SSH.
- **KDE Plasma** — curated desktop with theming, shortcuts, and Fcitx5 Chinese input.
- **Headless boards** — single-board computers (`jasonkwh-bcm2711`, `jasonkwh-bcm2710a1`) run a stripped, headless profile: no desktop/Steam/GPU stack, shared CLI tools (including `gh`), zram swap; SD images via `make image <host>`. Wi-Fi + Tailscale enrolment come from `~/.secrets/headless-env` (`make headless-env`).
- **Dev-ready** — containers (Podman), Kubernetes tooling, cloud CLIs, and language runtimes.
- **Always in sync** — Tailscale (networking) + Syncthing (file sync) keep the fleet in lockstep.
- **Flake install** — boot the official NixOS minimal ISO and `nixos-install --flake github:jasonkwh/my-nixos-configurations#<host>`: no custom image to build, config comes straight from GitHub. See [docs/install.md](docs/install.md).
- **Private assistant** — Hermes Agent with a personal companion; one designated
  fleet host owns the WhatsApp gateway. See [小升升](#personal-assistant-小升升).

## Machine profiles

ShengOS supports any number of machines sharing a common base, keeping hardware-specific configuration scoped per-host. Both x86_64-linux and aarch64-linux (ARM boards) are supported:

| Profile | Hardware | Notes |
|---------|----------|-------|
| **`jasonkwh-7520u`** | AMD Ryzen 5 7520U · AMD Radeon 610M · 16GB | Daily driver — Steam, gaming, hibernation |
| **`jasonkwh-7300u`** | Intel Core i5-7300U · Intel HD Graphics 620 · 8GB | Spare laptop — hibernates to NVMe swap |
| **`jasonkwh-1650v2`** | Intel Xeon E5-1650 v2 · AMD FirePro D500 x 2 · 64GB | Mac Pro 2013 (trashcan) — emulation/retro gaming + Tailscale node |
| **`jasonkwh-bcm2711`** | Broadcom BCM2711 · Broadcom VideoCore VI · 4GB | Headless Hermes + WhatsApp gateway — no desktop, zram, SD card |
| **`jasonkwh-bcm2710a1`** | Broadcom BCM2710A1 · Broadcom VideoCore IV · 512MB | Headless Syncthing backup node — Hermes disabled, zram-only swap, SD card |

### Distributed build pool

Builders are derived from `hostDefs` in `flake.nix`: any host declaring
`isBuilder = true` joins the pool for its architecture. `buildSpeed` provides
relative scheduling weight and `maxBuildJobs` limits concurrency. Each client
uses reachable, same-architecture peers except itself. Authentication uses
Tailscale SSH, and `jasonkwh` is trusted by the remote Nix daemon. Upgrade
commands probe the active generation's `/etc/nix/machines`, avoiding a second
flake evaluation; builder-topology changes take effect after activation.

`mkHost` uses `hostSystem`, `isLaptop`, and `isHeadless` to select system and
Home Manager layers. Setting neither class flag creates a desktop host.
`isHermesWhatsappGateway = true` designates the single Hermes-enabled
WhatsApp gateway, currently `jasonkwh-bcm2711`. x86 desktop hosts can build
aarch64 SD images through QEMU binfmt emulation.

## Quick start

`meow` wraps this repository's `Makefile` and works from any directory:

```bash
meow update          # nix flake update — refresh flake inputs
meow upgrade         # rebuild + activate the current host's config
```

See [Command reference](#command-reference) for the full list, or [docs/install.md](docs/install.md) to install ShengOS on a new machine.

## Personal assistant (小升升)

ShengOS ships with a personal AI assistant — **小升升** — a private companion
that lives on the machine, answers to its owner, and looks after them day to
day. She runs from the flake on Hermes-enabled hosts, and memories and skills
stay in sync via Tailscale and Syncthing. WhatsApp is intentionally active on
only the host marked `isHermesWhatsappGateway`; its Baileys session remains
local to that host and must be paired there.

## Command reference

| Command | Description |
|---------|-------------|
| `meow upgrade` | Rebuild + activate the current host; BCM2710A1 automatically evaluates/builds on BCM2711 |
| `meow boot` | Rebuild for next reboot (also cleans `/boot`) |
| `meow update` | Refresh flake inputs (`nix flake update`) |
| `meow gc` | Delete old generations + refresh bootloader |
| `meow image <hostname>` | Build an SD-card image for a host, e.g. `meow image jasonkwh-bcm2711` → `result/*.img.zst` |
| `meow headless-env` | Export the build host's Wi-Fi credentials (+ optional Tailscale auth key) into `~/.secrets/headless-env` for headless boards |
| `meow <hostname>` | Rebuild a specific host (e.g. `meow jasonkwh-7520u`) |
| `meow syncthing-init` | One-time bootstrap of Syncthing identity on a new machine; prints the device ID to register in `flake.nix`'s `hostDefs` |

`upgrade` defaults to the machine's hostname; use `HOST=` or a host target to
select another configuration.
On the 512MB BCM2710A1, `upgrade` streams the current configuration to the
BCM2711 over Tailscale SSH. The BCM2711 fetches inputs, evaluates and builds;
only the finished system closure is copied back for local activation. The
BCM2711 must therefore be online and reachable as
`jasonkwh-bcm2711.tail0c0276.ts.net`.

## Repository layout

```
flake.nix            # Entry point — inputs, hosts
misc/                # Non-module assets: SOUL.md, export-headless-env.sh,
                     # remote-builders.sh
cluster/             # Per-host & shared NixOS config
  common/            #   Shared across all machines (branding, fonts, services…)
                     #   headless.nix — imported when isHeadless = true
                     #   home.nix — HM entry point routing home-headless/-desktop/-laptop
  7520u/             #   AMD Ryzen 5 7520U host
  7300u/             #   Intel Core i5-7300U host
  1650v2/            #   Mac Pro 2013 (trashcan) — emulation/retro gaming
  bcm2711/           #   Raspberry Pi 4B headless host (aarch64)
  bcm2710a1/         #   BCM2710A1 headless host (aarch64)

docs/                # Guides (install, troubleshooting, …)
assets/              # Logos, wallpapers
version.yaml         # Current release version (auto-bumped by CI)
.github/workflows/   # CI — self-hosted deploy + auto versioning
```

## Versioning

The current release is tracked in `version.yaml`. On every push to `main`, the **Bump Version** workflow reads the current version, bumps it (patch by default, or `minor`/`major` via `workflow_dispatch`), commits the update, and tags the release as `vX.Y.Z` (semver).
