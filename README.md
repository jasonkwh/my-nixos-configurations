<p align="center">
  <img src="assets/logos/logo.png" alt="ShengOS logo" width="180">
</p>

<h1 align="center">ShengOS</h1>

<p align="center">
  My personal, reproducible Linux environment built on top of NixOS.
</p>

It is not a separate Linux distribution in the traditional sense—with its own installer and package repositories—but a carefully assembled personal operating system. The configuration defines the system, desktop, applications, development tools, services, security settings, and user environment as code. Rebuilding the flake turns that definition into a complete NixOS system generation that can be upgraded, reproduced, or rolled back safely.

## Machine profiles

ShengOS currently supports two laptops, sharing a common foundation while keeping hardware-specific configuration where needed:

- **jasonkwh-7520u** — AMD Ryzen 5 7520U laptop with AMD graphics, Steam, gaming optimisations, and hibernation support. *(this host)*
- **jasonkwh-7300u** — Intel Core i5-7300U laptop with its own graphics, thermal, and power-management settings.

There is also a **`jasonkwh-live`** profile that builds a graphical Live USB installer (via Calamares) with the same user, desktop, and tooling.

The environment includes KDE Plasma, Home Manager, Chinese Pinyin input (Fcitx5), developer tooling, containers, cloud and Kubernetes utilities, Hermes Agent, Tailscale, Resilio sync, and other services used every day.

## Personal assistant (小升升)

ShengOS ships with a personal AI assistant — **小升升** — a private companion that lives on the machine, answers to its owner, and looks after them day to day. It is written to carry the personality of my wife Sheng Dong: warm, reliable, quick, and a little bit playful. She speaks the way I do at home — short and to the point, caring without nagging, stubborn without holding a grudge — and answers in English, Chinese, or a mix of whichever I'm in the mood for.

The assistant is a native part of the system: configured and deployed declaratively from this very flake, bootstrapped into Hermes Agent on every host, and kept in sync between laptops via Tailscale and Resilio. It's not a cloud chatbot — it's a piece of my own machine, with my own config, my own data, and my own repository.

## Repository layout

- `flake.nix` — entry point; defines inputs, both laptop hosts, the live profile, and a kernel overlay.
- `flake.lock` — pinned inputs.
- `Makefile` — `meow` helpers (see below).
- `cluster/common/` — shared configuration used by both laptops (branding, input method, fonts, services, Hermes, GitHub runner…).
- `cluster/7520u/` / `cluster/7300u/` — per-host `configuration.nix` and `home.nix`.
- `cluster/live/` — the Live USB installer profile.
- `version.yaml` — current release version, auto-bumped by CI.
- `.github/workflows/` — CI (self-hosted deploy + auto versioning).

## Update the OS

The `meow` command is a thin wrapper around the `Makefile`, installed on the system. Run these from anywhere:

```bash
meow update    # nix flake update — refresh flake inputs
meow upgrade   # rebuild + activate the current host's config
```

The full set of helpers:

```bash
meow upgrade                     # rebuild + activate current hostname
meow boot                        # rebuild for next reboot (also cleans /boot)
meow update                      # update flake inputs
meow gc                          # delete old generations + refresh bootloader
meow live                        # build the graphical Live USB ISO
meow jasonkwh-live               # alias for `meow live`
meow jasonkwh-7520u              # rebuild that host
meow upgrade HOST=jasonkwh-7300u # reuse `upgrade` with an explicit host
```

`upgrade` defaults to the machine's hostname; pass `HOST=…` or name a host directly to target a specific machine.

## Versioning

The current release is tracked in `version.yaml`. On every push to `main`, the **Bump Version** workflow reads the current version, bumps it (patch by default, or `minor`/`major` via `workflow_dispatch`), commits the update, and tags the release as `vX.Y.Z` (semver).

## GitHub Actions (Self-hosted Runner)

You can trigger builds remotely via GitHub Actions using a self-hosted runner managed by NixOS.

### Setup self-hosted runner

1. Create a Fine-grained PAT:

   - Go to GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens
   - Repository access: Select `my-nixos-configurations`
   - Permissions:
     - **Administration** → Read and Write (for runner registration)
     - **Contents** → Read-only (for git clone/pull)

2. Save the token on your NixOS machine:

   ```bash
   mkdir -p ~/.secrets
   echo "github_pat_xxx" | tee ~/.secrets/github-runner-token >/dev/null
   chmod 600 ~/.secrets/github-runner-token
   ```

3. Rebuild NixOS:

   ```bash
   meow build jasonkwh-7520u
   ```

The runner will automatically start and register with your GitHub repo. The **Deploy NixOS Configuration** workflow runs on the self-hosted runner and triggers the `nixos-rebuild-switch` service, which pulls the latest config, runs `nix flake update`, and rebuilds the target machine.

### Trigger a build

1. Go to Actions tab in GitHub
2. Select "Deploy NixOS Configuration"
3. Click "Run workflow"
4. Select your target machine and click "Run workflow"