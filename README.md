<p align="center">
  <img src="assets/logos/logo.png" alt="ShengOS logo" width="180">
</p>

<h1 align="center">ShengOS</h1>

<p align="center">
  My personal, reproducible, AI-native Linux environment built on NixOS.
</p>

<p align="center">
  <a href="docs/install.md"><b>📦 Installation Guide</b></a>
  ·
  <a href="#quick-start">Quick start</a>
  ·
  <a href="#fleet">Fleet</a>
  ·
  <a href="#commands">Commands</a>
</p>

---

A multi-machine [NixOS](https://nixos.org/) flake: system, desktop, services,
and the resident assistant (小升升) are declared here and reproduced across
the fleet. Hermes can operate a host, but it may only activate store paths
the owner has verified with `shengos-switch`.

- **Lockstep fleet** — Tailscale SSH + Syncthing; `isBuilder` hosts share
  same-architecture builds. `jasonkwh-bcm2711` is the hub (WhatsApp,
  Prometheus 14d, Grafana `:3001`).
- **Desktop or board** — Plasma (theming, shortcuts, Fcitx5) on laptops and
  the Mac Pro; headless boards skip the GUI/Steam/GPU stack, use zram, and
  enrol from `~/.secrets/headless-env`.
- **Dev-ready** — Podman, Kubernetes tooling, cloud CLIs, language runtimes.

## Quick start

`meow` wraps this repo's `Makefile` and works from any directory:

```bash
meow update          # refresh flake inputs
meow upgrade         # rebuild + activate this host
```

New machine: [docs/install.md](docs/install.md).

## Fleet

Hosts are declared in `flake.nix` (`hostDefs`). `isLaptop` / `isHeadless` /
`isFleetHub` / `isBuilder` select the shared modules. x86 hosts can
cross-build the Pi SD image.

| Host | Hardware |
|------|----------|
| **`jasonkwh-7520u`** | AMD Ryzen 5 7520U · AMD Radeon 610M · 16GB |
| **`jasonkwh-7300u`** | Intel Core i5-7300U · Intel HD Graphics 620 · 8GB |
| **`jasonkwh-2450m`** | Intel Core i5-2450M · AMD Radeon HD 6630M · 16GB |
| **`jasonkwh-3210m`** | Intel Core i3-3210M · Intel HD Graphics 4000 + NVIDIA GeForce GT 640M LE · 12GB |
| **`jasonkwh-1650v2`** | Intel Xeon E5-1650 v2 · AMD FirePro D500 x2 · 64GB |
| **`jasonkwh-bcm2711`** | Broadcom BCM2711 · Broadcom VideoCore VI · 4GB |

`jasonkwh-bcm2711` is the fleet hub — WhatsApp gateway, Prometheus (14d),
and Grafana. Every host exports `node_exporter` on `tailscale0:9100`;
Prometheus scrapes all `hostDefs` targets via MagicDNS. Grafana (set the
admin password on first login):
`http://jasonkwh-bcm2711.tail0c0276.ts.net:3001`.

小升升 runs on Hermes-enabled hosts. Memories and skills sync over Syncthing;
the WhatsApp gateway lives only on the hub.

## Commands

| Command | Description |
|---------|-------------|
| `meow upgrade` | Rebuild + activate this host |
| `meow boot` | Rebuild for next reboot (also cleans `/boot`) |
| `meow update` | `nix flake update` |
| `meow gc` | Delete old generations + refresh bootloader |
| `meow image <host>` | SD image, e.g. `jasonkwh-bcm2711` → `result/sd-image/*.img.zst` |
| `meow headless-env` | Write Wi-Fi (+ optional Tailscale key) into `~/.secrets/headless-env` |
| `meow syncthing-init` | Bootstrap Syncthing identity; print device ID for `hostDefs` |
| `meow secrets-backup` | Encrypt `~/.secrets` to `secrets.tar.enc` |
| `meow secrets-restore` | Restore `~/.secrets` (modes + ACLs) |
| `meow <hostname>` | Rebuild a named host (e.g. `jasonkwh-7520u`) |

`upgrade` uses the machine hostname unless you set `HOST=` or pass a host
target.

## Layout

```
flake.nix              # inputs + hostDefs
cluster/               # NixOS + Home Manager
  common/              # shared modules
  7520u/ 7300u/ 2450m/ 3210m/ 1650v2/ bcm2711/
misc/                  # SOUL.md, Grafana dashboards, helper scripts
docs/install.md
assets/
version.yaml           # bumped on push to main
.github/workflows/
```

## Versioning

`version.yaml` is the release number. On every push to `main`, **Bump
Version** bumps patch (or `minor`/`major` via `workflow_dispatch`), commits,
and tags `vX.Y.Z`.
