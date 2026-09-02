# ShengOS Installation Guide

This document explains how to install ShengOS on a brand-new machine and restore a full development environment. Two paths:

- **x86 laptop/desktop** — install from the Live USB, then follow Steps 2–6.
- **ARM board / headless node (`jasonkwh-bcm2711`, `jasonkwh-bcm2710a1`)** — skip the Live USB; see "Headless board path" at the end.

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
"jasonkwh-<new-hostname>" = mkHost {
  name = "<new-hostname>";
  hostSystem = "x86_64-linux";   # or "aarch64-linux" for ARM boards
  isLaptop = true;               # laptops only: lid/Wayland/battery extras
  isHeadless = true;             # boards only: strips Plasma/GUI/Steam/GPU
};
```

Set neither flag for a regular x86 desktop. Home Manager file selection is automatic: `cluster/common/home.nix` routes the shared CLI core plus desktop/laptop layers based on these flags — only put machine-specific packages in the copied `cluster/<host>/home.nix`.

> Each host's `hardware-configuration.nix` lives in the repo at `cluster/<host>/` and is picked up automatically by `mkHost` — do not regenerate it for fun. A leftover `/etc/nixos/` directory on installed machines is a stale legacy copy: never edit it.

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
scp -r jasonkwh@jasonkwh-7520u:~/.secrets/ ~/
```

### Q: How does SSH access work between machines?
Fleet SSH goes through **Tailscale SSH** (`services.tailscale.extraSetFlags = [ "--ssh" ]`):
no authorized_keys to distribute, password auth disabled, port 22 reachable only on
`tailscale0`. Connect by tailnet hostname:

```bash
ssh jasonkwh@jasonkwh-7520u     # or any jasonkwh-<host>
```

Access is revoked in the Tailscale admin console (expire/remove the device's node key).

### Q: How does file sync work, and where is the Syncthing device ID?
Hermes' memories and skills folders sync via **Syncthing**. Devices trust
each other by device ID — there are no shared secrets to copy.

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

### Q: How do distributed builds work?
Any host declaring `buildSpeed` and `maxBuildJobs` in `flake.nix`'s `hostDefs`
joins the fleet builder pool (see README "Distributed build pool"). During a
rebuild, local jobs fill first; overflow derivations are dispatched to pooled
peers over Tailscale SSH. A peer that is offline is simply skipped — builds
never hang waiting for it. To add a machine to the pool, set its two numbers
in `hostDefs`; to add a whole new architecture, extend the per-arch list in
`cluster/common/configuration.nix`.

### Q: Installing on a Mac Pro 2013 (trashcan)?
Supported via the standard Live USB path. The Live image already carries the
hardware fixes this machine needs (added to `cluster/live/configuration.nix`):

- **Graphics**: FirePro D300/D700 (GCN1) via modern amdgpu — kernel params
  `radeon.si_support=0 amdgpu.si_support=1 amdgpu.dc=1`.
- **Stability**: `intel_iommu=off` — without it the machine crashes randomly
  (hinted by the [Debian wiki page for MacPro6,1](https://wiki.debian.org/InstallingDebianOn/Apple/MacPro/6-1)).
- **Wi-Fi**: BCM4360 (14e4:43a0) only works with the out-of-tree
  `broadcom_sta` driver, accepted as a deliberately permitted insecure
  package. **Plug in Ethernet anyway** — the Wi-Fi driver is known to be
  flaky in the community, and Ethernet is the reliable path for install.

When you create the permanent `cluster/macpro/` host config, mirror these
settings there (the Live USB only covers the install phase) and decide the
bootloader variant then: GRUB with standard NVRAM entries is the default, but
Mac firmware occasionally drops NVRAM entries — if boot becomes unreliable,
switch to `boot.loader.grub.efiInstallAsRemovable = true`.

## Headless board path (jasonkwh-bcm2711 / jasonkwh-bcm2710a1)

Boards without a desktop are installed from an SD card image, not the Live USB.
Examples: `jasonkwh-bcm2711` (Pi 4B, 4GB) and `jasonkwh-bcm2710a1` (BCM2710A1,
512MB). Headless boards get their Wi-Fi credentials and Tailscale auth key from
`~/.secrets/headless-env` on the build host — create it first:

```bash
# On a laptop connected to the home Wi-Fi:
TS_AUTH_KEY=<paste from https://login.tailscale.com/admin/settings/keys> \
  make headless-env
# → writes ssid_home / psk_home / ts_auth_key into ~/.secrets/headless-env
```

For the Tailscale key: generate an **auth key** in the admin console with
`reusable=on` (limit to the number of boards), `ephemeral=on`, `tag:fleet`.

1. **Build the image** on an x86 host (binfmt emulation is enabled
   automatically for x86 non-headless hosts):

   ```bash
   make image jasonkwh-bcm2711      # Pi 4B
   make image jasonkwh-bcm2710a1    # bcm2710a1
   zstd -d result/sd-image/*.img.zst
   sudo dd if=result/sd-image/*.img of=/dev/sdX bs=4M status=progress
   ```

2. **First boot**: insert the card, power on. Wi-Fi and Tailscale enrolment
   are automatic — the enrol service reads the baked-in `ts_auth_key` and
   joins the tailnet without interaction. SSH works via Tailscale SSH from
   then on.
3. **Copy repo + secrets** from an existing machine over Tailscale (only
   needed if `headless-env` wasn't baked in at image time):

   ```bash
   rsync -a jasonkwh@<source>:Documents/my-nixos-configurations ~/Documents/
   rsync -a jasonkwh@<source>:.secrets ~/
   ```

4. **Syncthing identity** — before the first rebuild, pre-generate it:

   ```bash
   cd ~/Documents/my-nixos-configurations
   make syncthing-init    # prints this machine's device ID
   ```

5. **Register everywhere**: paste the device ID into
   `cluster/common/configuration.nix` (`syncthingDevices` map + both folder
   `devices` lists), commit, pull on the other machines, rebuild them.
6. **Build and switch on the board**: `make upgrade`.

The `bcm2710a1` host has no nixos-hardware module, so its SD image uses the
generic aarch64 firmware set (`bcm2710-rpi-zero-2-w.dtb` is included).

The Pi boots via Broadcom firmware + extlinux (`boot.loader.generic-extlinux-compatible`),
not UEFI — its `cluster/bcm2711/configuration.nix` overrides the common
systemd-boot defaults with `mkForce`. The hardware layout
(`cluster/bcm2711/hardware-configuration.nix`) is committed to the repo, so a
freshly flashed card needs no `nixos-generate-config` step.
