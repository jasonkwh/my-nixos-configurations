# my-nixos-configurations

My personal NixOS configuration nix files

## Apply the config on NixOS

### 7520u laptop

```bash
sudo nixos-rebuild switch --flake .#jasonkwh-7520u --impure --upgrade-all
```

### 7300u laptop

```bash
sudo nixos-rebuild switch --flake .#jasonkwh-7300u --impure --upgrade-all
```

## Distrobox Setup (for SteamOS, Fedora Silverblue, or any immutable OS)

For immutable operating systems where the root filesystem gets wiped on updates, use distrobox with a separate home directory.

### First-time setup (run on host)

```bash
# Create distrobox with its own home directory
mkdir -p ~/distrobox-homes/fedora-dev
distrobox-create --name fedora-dev --image registry.fedoraproject.org/fedora-toolbox:43 --home ~/distrobox-homes/fedora-dev

# Enter the distrobox
distrobox enter fedora-dev
```

### Inside the distrobox

```bash
# Clone this repo
git clone https://github.com/jasonkwh/my-nixos-configurations.git
cd my-nixos-configurations

# Run the bootstrap script
./distrobox-bootstrap.sh

# Restart shell and configure powerlevel10k
exec zsh
p10k configure
```
