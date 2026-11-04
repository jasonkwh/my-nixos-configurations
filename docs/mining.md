<p align="center">
  <img src="../assets/logos/logo_mining.png" alt="Mining logo" width="200">
</p>

<h1 align="center">Mining</h1>

Desktop hosts (`!isHeadless` — laptops and the Mac Pro) install XMRig and
write `~/.config/xmrig.json` from `cluster/common/nixos/xmrig.nix`. The Steam Deck
gets the same file from `homeConfigurations.jasonkwh-deck`
(`cluster/common/home/xmrig.nix`) with huge pages off. The headless hub
does not mine.

Wallet and pool list are the `monero` attrset in `flake.nix`. `monero.pools`
is tried in order; later entries are failover. MoneroOcean ports in the
`2xxxx` range are TLS; a `1xxxx` port with `tls = true` will not connect.
Kryptex XMR uses `8029` for TLS and `7029` for plain TCP.

The module reserves 1200 huge pages, loads `msr` with writes allowed, and
wraps `xmrig` with `cap_sys_rawio` so RandomX can use MSR and huge pages.
CPU threads yield so the desktop stays usable. The HTTP API listens on
port `16000`, reachable from other Tailscale machines.

```bash
xmrig
```
