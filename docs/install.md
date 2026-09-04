# ShengOS Installation Guide

Choose the path for the target hardware:

- **x86 laptop/desktop** — follow Steps 1–5 using the official NixOS minimal ISO.
- **ARM headless node** — skip the ISO and use the
  [headless board path](#headless-board-path-jasonkwh-bcm2711--jasonkwh-bcm2710a1).

Use an existing machine as the source of truth and transfer secrets only over
an encrypted Tailscale connection.

## Prerequisites

- The official NixOS minimal ISO (download from nixos.org, written to a USB stick — no custom image to build)
- Network connectivity on the target machine (Ethernet preferred; see the Mac Pro FAQ for Wi-Fi caveats)
- The target host already registered in the flake (see Step 1)
- An already-configured machine (e.g. `jasonkwh-7520u`) acting as the source for secrets

## Step 1: Register the host in the flake (on an existing machine, before install)

1. Copy an existing host (e.g. `cluster/7520u/`) to `cluster/<new-hostname>/` and adjust as needed. Add the host to `hostDefs` in `flake.nix`:

```nix
"jasonkwh-<new-hostname>" = {
  name = "<new-hostname>";
  hostSystem = "x86_64-linux";   # or "aarch64-linux" for ARM boards
  isLaptop = true;               # laptops only: lid/Wayland/battery extras
  isHeadless = true;             # boards only: strips Plasma/GUI/Steam/GPU
  syncthingId = "<device-id>";    # omit until the real ID is available
  # isHermesWhatsappGateway = true; # optional; exactly one fleet host
};
```

Set neither class flag for a regular x86 desktop. Home Manager file selection
is automatic: `cluster/common/home.nix` routes the shared CLI core plus
desktop/laptop layers based on these flags — only put machine-specific
packages in the copied `cluster/<host>/home.nix`.

`isHermesWhatsappGateway` is separate from the host class. Set it on exactly
one Hermes-enabled host to add `WHATSAPP_ENABLED=true`; leave it absent
everywhere else. A host with Hermes disabled cannot activate WhatsApp even if
the flag is accidentally set.

2. Commit and push. During installation, the host falls back to
   `/etc/nixos/hardware-configuration.nix`, generated in Step 2. A committed
   `cluster/<new-hostname>/hardware-configuration.nix` takes priority.

## Step 2: Boot the minimal ISO and install

1. Boot the official NixOS minimal ISO, connect to the network.
2. Partition and mount the target disk (UEFI: ESP + root), e.g.:

```bash
sudo parted /dev/sda -- mklabel gpt mkpart ESP fat32 1MiB 512MiB set 1 esp on mkpart primary 512MiB 100%
sudo mkfs.fat -F32 /dev/sda1 && sudo mkfs.ext4 /dev/sda2
sudo mount /dev/sda2 /mnt && sudo mkdir -p /mnt/boot && sudo mount /dev/sda1 /mnt/boot
sudo nixos-generate-config --root /mnt
```

3. Recommended: copy
   `/mnt/etc/nixos/hardware-configuration.nix` to
   `cluster/<new-hostname>/hardware-configuration.nix`, then commit and push.
   Until then, the flake uses `/etc/nixos/hardware-configuration.nix`.
4. Install straight from the GitHub flake:

```bash
sudo nixos-install --flake github:jasonkwh/my-nixos-configurations#jasonkwh-<new-hostname>
```

5. Set the user password (`passwd` inside the installed system via `sudo nixos-enter` or on first boot) and reboot.

## Step 3: First boot — clone the repo

```bash
git clone https://github.com/jasonkwh/my-nixos-configurations.git ~/Documents/my-nixos-configurations
```

(On fresh installs the repo is not pre-copied; cloning it directly is the source of truth.)

## Step 4: Pair Syncthing (fleet file sync)

Hermes' memories and skills folders sync across the fleet via Syncthing. Each
device has a unique device ID that must be registered in
`flake.nix` under its `hostDefs` entry — a fresh machine is not known to the fleet
until you complete this step:

1. Generate the device identity and print the new machine's device ID:

   ```bash
   cd ~/Documents/my-nixos-configurations
   make syncthing-init    # idempotent; needs sudo once (chown to hermes)
   ```

2. Paste the printed ID into the host's `syncthingId` in `flake.nix` under
   `hostDefs`, commit, and pull on the other machines.
3. Rebuild both machines (`make upgrade`). Verify pairing:

   ```bash
   systemctl status syncthing
   sudo journalctl -u syncthing | grep -i 'established\|connected'
   ```

Device IDs are public-key fingerprints — safe to commit to GitHub. The private
key lives in `/var/lib/syncthing-hermes/.config/syncthing/` and never leaves
the machine.

## Step 5: Verify

```bash
hostname          # should print the new hostname
fastfetch         # check system info and that the branding reads "ShengOS"
```

## FAQ

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
Syncthing pairs devices by public device ID; no shared secret is committed.
Follow [Step 4](#step-4-pair-syncthing-fleet-file-sync) to generate and
register the ID. Its private key remains under
`/var/lib/syncthing-hermes/.config/syncthing/`.

### Q: The new machine has no memories yet — can it overwrite the old machine's data?
No. Syncthing only exchanges data between devices that have each other's device
ID registered. A fresh node pairs with an empty/unknown state only after you
complete the pairing step above; both folders also use trashcan versioning
(14-day retention) as a safety net against accidental overwrites.

### Q: How do I move the Hermes WhatsApp gateway to another host?
Move `isHermesWhatsappGateway = true` to the target host in `flake.nix`. Rebuild
the old gateway first so its WhatsApp bridge stops, then rebuild the new
gateway; this avoids both bridges running simultaneously during the change.

The Baileys WhatsApp session is host-local and is deliberately not synchronized
by Syncthing. Pair WhatsApp on the new gateway with `hermes whatsapp` if that
host does not already have a valid session.

### Q: How do distributed builds work?
Hosts with `isBuilder = true` in `hostDefs` join the pool for their
architecture; `buildSpeed` and `maxBuildJobs` tune scheduling. Reachable peers
are selected through Tailscale SSH. Offline peers are skipped, except that the
BCM2710A1's low-memory upgrade path explicitly requires BCM2711.

### Q: Installing on a Mac Pro 2013 (trashcan)?
Registered as `jasonkwh-1650v2` in this repo — `cluster/1650v2/configuration.nix`
carries the hardware fixes (from the
[Debian wiki page for MacPro6,1](https://wiki.debian.org/InstallingDebianOn/Apple/MacPro/6-1)):

- **Graphics**: FirePro D300/D700 (GCN1) via modern amdgpu — kernel params
  `radeon.si_support=0 amdgpu.si_support=1 amdgpu.dc=1 amdgpu.dpm=0`.
- **Stability**: `intel_iommu=off` — without it the machine crashes randomly.
- **Fans**: mbpfan drives the Apple SMC fan curve; without it the twin fans
  misbehave (constant loud or insufficient cooling).
- **Wi-Fi**: BCM4360 (14e4:43a0) only works with the out-of-tree
  `broadcom_sta` driver, accepted as a deliberately permitted insecure
  package. **Plug in Ethernet anyway** — the Wi-Fi driver is known to be
  flaky in the community, and Ethernet is the reliable path for install.

Install via the minimal ISO path (Step 2). Bootloader note: GRUB with
standard NVRAM entries is the default, but Mac firmware occasionally drops
NVRAM entries — if boot becomes unreliable, switch to
`boot.loader.grub.efiInstallAsRemovable = true`.

## Headless board path (jasonkwh-bcm2711 / jasonkwh-bcm2710a1)

Install headless boards from an SD-card image rather than the minimal ISO.
Supported examples are `jasonkwh-bcm2711` (Pi 4B, 4GB) and
`jasonkwh-bcm2710a1` (Zero 2 W, 512MB). First create
`~/.secrets/headless-env` on the build host:

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
3. **Copy the repo and secrets if absent** from an existing machine over
   Tailscale:

   ```bash
   rsync -a jasonkwh@<source>:Documents/my-nixos-configurations ~/Documents/
   rsync -a jasonkwh@<source>:.secrets ~/
   ```

4. **Syncthing identity** — before the first rebuild, pre-generate it:

   ```bash
   cd ~/Documents/my-nixos-configurations
   make syncthing-init    # prints this machine's device ID
   ```

5. **Register everywhere**: paste the device ID into the board's
   `syncthingId` in `flake.nix` under `hostDefs`; the fleet device and folder
   lists are derived automatically. Commit, pull on the other machines, and
   rebuild them.
6. **Build and switch on the board**: `make upgrade`.

   On `jasonkwh-bcm2710a1`, this command automatically streams the current
   configuration to `jasonkwh-bcm2711.tail0c0276.ts.net` over Tailscale SSH.
   The BCM2711 performs input fetching, evaluation, and building so the Zero
   2 W does not exhaust its 512MB RAM. The completed system closure is copied
   back and activated locally. Ensure BCM2711 is online and reachable before
   upgrading BCM2710A1.

The `bcm2710a1` host has no nixos-hardware module, so its SD image uses the
generic aarch64 firmware set (`bcm2710-rpi-zero-2-w.dtb` is included).
It keeps Hermes disabled to fit its 512MB RAM, but runs Syncthing as an
explicitly provisioned `hermes` system user to provide a backup replica.

Both boards boot through Broadcom firmware and extlinux
(`boot.loader.generic-extlinux-compatible`), not UEFI. Their committed
hardware configurations mean a freshly flashed card does not need
`nixos-generate-config`.
