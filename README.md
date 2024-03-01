# my-nixos-configurations

My personal NixOS configuration nix files

## Apply the config on NixOS

### Local build

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos-jasonkwh --upgrade-all
```

### Remote build

```bash
sudo nixos-rebuild switch --fast --flake /etc/nixos#nixos-jasonkwh --upgrade-all --build-host jasonkwh@192.168.1.43 --use-remote-sudo
```
