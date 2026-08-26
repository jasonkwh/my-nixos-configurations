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
The entire system — desktop, applications, development tools, services, and security settings — is declared as code. Rebuilding the flake produces a complete NixOS generation that can be upgraded, reproduced, or rolled back safely.

## Features

- **Declarative everything** — system, user, and desktop config all live in this repo as code.
- **Reproducible builds** — `flake.lock` pins every dependency; switch machines freely.
- **KDE Plasma** — curated desktop with theming, shortcuts, and Fcitx5 Chinese input.
- **Dev-ready** — containers (Podman), Kubernetes tooling, cloud CLIs, and language runtimes.
- **Always in sync** — Tailscale (networking) + Syncthing (file sync) keep two laptops in lockstep.
- **One-USB install** — boot the Live USB, click through Calamares, and land on a full ShengOS machine: the config repo is copied over automatically and flakes work from the first rebuild.
- **Private assistant** — Hermes Agent with a personal companion. See [小升升](#personal-assistant-小升升).

## Machine profiles

ShengOS supports one Live USB profile and any number of laptops sharing a common base, keeping hardware-specific configuration scoped per-host:

| Profile | Hardware | Notes |
|---------|----------|-------|
| **`jasonkwh-7520u`** | AMD Ryzen 5 7520U · AMD Radeon 610M | Daily driver — Steam, gaming, hibernation |
| **`jasonkwh-7300u`** | Intel Core i5-7300U · Intel HD Graphics 620 | Spare laptop |
| **`jasonkwh-live`** | n/a | Graphical Calamares installer — auto-copies this repo to the target, flakes ready out of the box, autologin |

## Quick start

The `meow` command is a thin wrapper around the `Makefile`, maintained in this repo. Run from anywhere:

```bash
meow update          # nix flake update — refresh flake inputs
meow upgrade         # rebuild + activate the current host's config
```

See [Command reference](#command-reference) for the full list, or [docs/install.md](docs/install.md) to install ShengOS on a new machine.

## Personal assistant (小升升)

ShengOS ships with a personal AI assistant — **小升升** — a private companion that lives on the machine, answers to its owner, and looks after them day to day. She runs entirely from the flake, boots on every host, and stays in sync between laptops via Tailscale and Syncthing. No cloud, no telemetry — just your own machine.

## Command reference

| Command | Description |
|---------|-------------|
| `meow upgrade` | Rebuild + activate the current host (`HOST=` to override) |
| `meow boot` | Rebuild for next reboot (also cleans `/boot`) |
| `meow update` | Refresh flake inputs (`nix flake update`) |
| `meow gc` | Delete old generations + refresh bootloader |
| `meow live` | Build the graphical Live USB ISO |
| `meow <hostname>` | Rebuild a specific host (e.g. `meow jasonkwh-7520u`) |
| `meow syncthing-init` | One-time bootstrap of Syncthing identity on a new machine; prints the device ID to register in `cluster/common/configuration.nix` |

`upgrade` defaults to the machine's hostname; pass `HOST=` or name a host directly to target a specific machine.

## Repository layout

```
flake.nix            # Entry point — inputs, hosts, kernel overlay
cluster/             # Per-host & shared NixOS config
  common/            #   Shared across all machines (branding, fonts, services…)
  7520u/             #   AMD Ryzen 5 7520U host
  7300u/             #   Intel Core i5-7300U host
  live/              #   Live USB installer profile
docs/                # Guides (install, troubleshooting, …)
assets/              # Logos, wallpapers
version.yaml         # Current release version (auto-bumped by CI)
.github/workflows/   # CI — self-hosted deploy + auto versioning
```

## Versioning

The current release is tracked in `version.yaml`. On every push to `main`, the **Bump Version** workflow reads the current version, bumps it (patch by default, or `minor`/`major` via `workflow_dispatch`), commits the update, and tags the release as `vX.Y.Z` (semver).
