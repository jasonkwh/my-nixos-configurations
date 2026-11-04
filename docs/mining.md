<p align="center">
  <img src="../assets/logos/logo_mining.png" alt="Mining logo" width="200">
</p>

<h1 align="center">Mining</h1>

Desktops mine Monero with XMRig. A Bitaxe on the LAN mines Bitcoin and stays
on all the time. The headless hub runs neither miner: it scrapes both and
serves the dashboard.

## Dashboard

Grafana on the hub, admin user `jasonkwh` (set the password on first login).
The dashboard is **ShengOS Mining**. The **Cryptocurrency** dropdown switches
the page; these open each side directly:

- [BTC](http://jasonkwh-bcm2711.tail0c0276.ts.net:3001/d/shengos-mining/shengos-mining?var-crypto=BTC)
- [XMR](http://jasonkwh-bcm2711.tail0c0276.ts.net:3001/d/shengos-mining/shengos-mining?var-crypto=XMR)

It refreshes every minute and opens on the last 6 hours. The definition is
`misc/grafana-mining.json`, provisioned by
`cluster/common/nixos/monitoring.nix`. `@moneroWallet@` and `@bitaxeIp@` in
that file are filled from `flake.nix` at build time, so the MoneroOcean and
Bitaxe links follow the wallet and the first Bitaxe address.

### BTC

Live AxeOS data (`/api/system/info`), scraped every 30 seconds. With more
than one device the stat panels sum or take the extreme across the fleet.

| Panel                 | What it shows                                                                                                                                      |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| Hashrate              | 1-minute average, summed, in TH/s                                                                                                                  |
| Efficiency            | Fleet watts per TH/s                                                                                                                               |
| Best diff             | Highest share any device has found. Click opens that Bitaxe's scoreboard                                                                          |
| Blocks found          | Blocks actually solved. A new one pages WhatsApp once                                                                                              |
| Accepted shares       | Total accepted                                                                                                                                     |
| Rejected shares       | Total rejected                                                                                                                                     |
| Distance to a block   | Network difficulty ÷ best share. Smaller is closer: green under 1,000, yellow under 100,000                                                        |
| ASIC temp             | Hottest die. Alert above 75°C for 10 minutes; about 50°C is normal at 525 MHz                                                                     |
| Power                 | Sum of watts across every device                                                                                                                   |
| WiFi                  | Weakest RSSI                                                                                                                                       |
| Fan                   | Fastest RPM                                                                                                                                        |
| Block height          | Height the ASICs are mining. Click opens the in-progress block on mempool.space                                                                   |
| Hashrate vs Expected  | Each device's 1-minute hashrate against the hashrate AxeOS expects                                                                                |

Three alerts go Alertmanager → Hermes → WhatsApp
(`misc/prometheus-fleet-rules.yml`):

| Alert              | When                                                                                          |
| ------------------ | --------------------------------------------------------------------------------------------- |
| `BitaxeMinerDown`  | Unreachable for 5 minutes. These devices are left plugged in and should always be mining     |
| `BitaxeOverheat`   | Die above 75°C for 10 minutes                                                                 |
| `BitaxeBlockFound` | `bitaxe_block_found` increases. Critical, sent once, with no resolve message                 |

### XMR

Per-host numbers come from XMRig's HTTP API. Wallet numbers come from the
MoneroOcean API, polled every 2 minutes into the node-exporter textfile on
the hub.

| Panel              | What it shows                                                                                          |
| ------------------ | ------------------------------------------------------------------------------------------------------ |
| Hashrate           | Sum of the 1-minute hashrate on miners that are running                                               |
| Hashrate by Miner  | Same series, one line per host                                                                         |
| Miners Online      | How many `xmrig` scrapes are up. Yellow at zero                                                        |
| Miners             | Table of 1-minute hashrate, good shares, best diff, and pool ping. The row name is the hostname       |
| Share of Network   | This wallet's hashrate ÷ Monero network hashrate, in parts per billion. Network hashrate is difficulty ÷ 120 |
| Valid Shares       | MoneroOcean wallet total                                                                               |
| Invalid Shares     | Stale and rejected shares on that wallet                                                               |
| Unpaid             | XMR waiting for payout. Click opens the wallet on MoneroOcean                                          |
| Paid               | XMR already paid out                                                                                   |

XMRig is started by hand, so a desktop that is off or not mining shows as
down. That is expected, and there is no alert for it. The Steam Deck is
left out of the scrape (see below). The wallet panels still count every
worker mining to MoneroOcean under `monero.wallet`, Deck included. Hashes
sent to the Kryptex failover pool stay off those wallet panels; the
per-host hashrate panels still show them, because they read the local API.

## Monero

Desktop NixOS hosts (`!isHeadless` — the laptops and the Mac Pro) install
XMRig and write `~/.config/xmrig.json` from `cluster/common/nixos/xmrig.nix`.
The Steam Deck gets the same file from `homeConfigurations.jasonkwh-deck`
(`cluster/common/home/xmrig.nix`).

Start it in a terminal. There is no systemd unit:

```bash
xmrig
```

XMRig looks next to its store binary and then at `~/.xmrig.json` before
`~/.config/xmrig.json`, and it logs `unable to open` for the first two.
`config OK` and the pool list mean the Home Manager file loaded. `autosave`
is off, so the process will not rewrite that file. Change the wallet or
pools in the `monero` attrset in `flake.nix`, then `meow upgrade`. A hand
edit of the JSON is replaced on the next activation.

`monero.pools` is tried in order. Later entries are failover. The pool
password is the hostname, which MoneroOcean shows as the worker name.
`solo = true` logs in as `solo:<wallet>`; a pool without that flag uses
the bare address.

| Pool                        | Port  | TLS | Login        |
| --------------------------- | ----- | --- | ------------ |
| `gulf.moneroocean.stream`   | 20004 | yes | wallet       |
| `xmr-sg.kryptex.network`    | 8029  | yes | `solo:wallet`|

MoneroOcean ports in the `2xxxx` range are TLS. A `1xxxx` port with
`tls = true` will not connect. Kryptex XMR uses `8029` for TLS and `7029`
for plain TCP.

CPU settings keep the desktop usable: threads yield, priority is left
unset, and `max-threads-hint` is 100. `donate-level` is 0.

### Huge pages and MSR

On NixOS the module reserves 1200 huge pages (`vm.nr_hugepages`, about
2.4 GiB), loads `msr` with `msr.allow_writes=on`, gives the `wheel` group
read-write on `/dev/msr*`, and wraps `xmrig` with `cap_sys_rawio` so
RandomX can use MSR and huge pages.

The Deck cannot apply that kernel setup. Its config turns huge pages off.
Prometheus also skips `isSteamMachine`, so the Deck never joins the
`xmrig` scrape list.

### HTTP API

The API listens on `0.0.0.0:16000` with `restricted` on, so it is
read-only. The firewall opens that port only on `tailscale0`. From another
tailnet machine:

```bash
curl -s http://jasonkwh-7520u.tail0c0276.ts.net:16000/2/summary
```

The hub's json_exporter reads
`http://<host>.tail0c0276.ts.net:16000/2/summary` for every non-headless
NixOS host. A new desktop joins the scrape when it lands in `hostDefs`.
Hashrate windows in that JSON are 10s, 60s, and 15m
(`hashrate.total[0]`, `[1]`, `[2]`). The dashboard's 1-minute panels use
the middle one.

## Bitcoin

Bitaxes run AxeOS on the LAN and have no Tailscale interface. They are the
only scrape targets reached by a raw IP. List them in `flake.nix`:

```nix
bitcoin.miners = [
  {
    name = "Bitaxe Gamma 601";
    ip_address = "192.168.4.20";
  }
];
```

Set that address as a static IP on the device. On DHCP the target drifts
and the job goes down. `name` is a note in the flake; Prometheus labels
the series with the IP. The hub must reach `http://<ip>/api/system/info`
on the LAN. After a change, `meow deploy jasonkwh-bcm2711` rebuilds the
scrape, the dashboard links, and the alerts.

The scoreboard link on **Best diff** points at the first entry in
`bitcoin.miners`.

`bitaxe_block_found` is the blocks actually solved. The coinbase-value
field in the AxeOS JSON is what a hypothetical block would pay, and it
moves on every block while `blockFound` stays 0.
