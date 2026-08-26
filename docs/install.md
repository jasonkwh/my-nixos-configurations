# ShengOS Installation Guide

This document explains how to install ShengOS on a brand-new machine from a Live USB and restore a full development environment.

**Core principle:** use an existing machine as the source of truth, and copy secrets over an encrypted channel (Tailscale) — never a plaintext USB stick.

## Prerequisites

- A ShengOS Live USB built with `make live`
- Network connectivity on the target machine
- An already-configured machine (e.g. `jasonkwh-7520u`) acting as the source for configuration and secrets

## Step 1: Boot from the Live USB and install

1. Boot from the Live USB to reach the graphical Calamares installer.
2. **The username must be `jasonkwh`** (pre-filled in the Calamares UI). The entire configuration repository hard-codes `/home/jasonkwh` and the username — a custom username is **not** supported.
3. After installation, Calamares runs a copy script that places this repository in the user's `~/Documents/`. The script also enables the `nix-command` and `flakes` experimental features in the installed system, so the first rebuild works out of the box.

## Step 2: First boot — update the repository

The `~/Documents/my-nixos-configurations` directory exists after install, but is a snapshot from when the Live USB was built (possibly outdated). Update it first:

```bash
cd ~/Documents/my-nixos-configurations
git pull origin main    # fetch the latest configuration
```

## Step 3: Add the new machine's host configuration

1. Copy an existing host (e.g. `cluster/7520u/`) to `cluster/<new-hostname>/` and adjust as needed.
2. Register the host in `flake.nix` under `nixosConfigurations`:

```nix
"jasonkwh-<new-hostname>" = mkHost { name = "<new-hostname>"; };
```

> Hardware-specific configuration (`hardware-configuration.nix`) lives in each machine's `/etc/nixos/` and is **not** committed to the repository.

## Step 4: Build and switch

Use the bundled `meow` wrapper (`meow` is an alias for the Makefile, which calls `nixos-rebuild switch`):

```bash
cd ~/Documents/my-nixos-configurations
./meow build <new-hostname>    # or: make <new-hostname>
```

## Step 5: Pair Syncthing (fleet file sync)

Hermes' memories and skills folders sync across the fleet via Syncthing. Each
device has a unique device ID that must be registered in
`cluster/common/configuration.nix` — a fresh machine is not known to the fleet
until you complete this step:

1. Generate the device identity and print the new machine's device ID:

   ```bash
   cd ~/Documents/my-nixos-configurations
   make syncthing-init    # idempotent; needs sudo once (chown to hermes)
   ```

2. Paste the printed ID into `cluster/common/configuration.nix` under
   `services.syncthing.settings.devices."jasonkwh-<hostname>".id`, commit, and
   pull on the other machines.
3. Rebuild both machines (`make upgrade`). Verify pairing:

   ```bash
   systemctl status syncthing-hermes
   sudo journalctl -u syncthing-hermes | grep -i 'established\|connected'
   ```

Device IDs are public-key fingerprints — safe to commit to GitHub. The private
key lives in `/var/lib/syncthing-hermes/.config/syncthing/` and never leaves
the machine.

## Step 6: Verify

```bash
hostname          # should print the new hostname
fastfetch         # check system info and that the branding reads "ShengOS"
```

## FAQ

### Q: The final installation step (copying the repository) fails with an error
The copy script now fails loudly instead of silently leaving a broken state. In almost all cases this means the username is not `jasonkwh` — the script verifies the target user exists before copying. Re-run the installer and make sure the username field is `jasonkwh` (it should be pre-filled).

### Q: Does the username have to be `jasonkwh`?
**Yes.** The username and `/home/jasonkwh` path are hard-coded throughout the repository. Custom usernames are not currently supported.

### Q: How do I migrate secrets (e.g. `~/.secrets/`)?
Prefer scp/rsync over an encrypted Tailscale link, never a plaintext USB stick:

```bash
scp -r jasonkwh@<7520U-IP>:~/.secrets/ ~/
```

### Q: How does file sync work, and where is the Syncthing device ID?
Hermes' memories and skills folders sync via **Syncthing** (the fleet no longer
uses Resilio). Unlike Resilio there are no shared folder secrets to copy —
devices trust each other by device ID instead.

The device ID is generated on first boot of the syncthing service. On a new
machine run:

```bash
cd ~/Documents/my-nixos-configurations
make syncthing-init    # pre-generates identity and prints the device ID
```

then paste it into `cluster/common/configuration.nix` under
`services.syncthing.settings.devices` (see Step 5 of this guide). Device IDs
are public-key fingerprints and are safe to commit to GitHub; the private key
stays in `/var/lib/syncthing-hermes/.config/syncthing/`.

### Q: The new machine has no memories yet — can it overwrite the old machine's data?
No. Syncthing only exchanges data between devices that have each other's device
ID registered. A fresh node pairs with an empty/unknown state only after you
complete the pairing step above; both folders also use trashcan versioning
(14-day retention) as a safety net against accidental overwrites.
