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

## Apply Home Manager on Debian (6267u)

### Prerequisites

1. Install Nix (multi-user/daemon mode):

   ```bash
   curl -L https://nixos.org/nix/install | sh -s -- --daemon
   ```

   Then restart your shell (or log out/in) so `nix` is on `PATH`.

2. Enable flakes:

   ```bash
   mkdir -p ~/.config/nix
   cat > ~/.config/nix/nix.conf << 'EOF'
   experimental-features = nix-command flakes
   EOF
   ```

3. No global Home Manager install is required (the Make target runs it via `nix run`).

### Apply

```bash
git clone https://github.com/jasonkwh/my-nixos-configurations.git
cd my-nixos-configurations
make jasonkwh-6267u
```

Note: the `jasonkwh-6267u` make target uses `nix run nixpkgs#home-manager -- switch -b backup --flake .#jasonkwh-6267u`, so if a managed file already exists (for example `~/.config/kwalletrc`), Home Manager will keep a `*.backup` copy instead of failing.

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
   echo "github_pat_xxx" | sudo tee /etc/github-runner-token
   sudo chmod 600 /etc/github-runner-token
   ```

3. Rebuild NixOS:

   ```bash
   make build jasonkwh-7520u
   ```

The runner will automatically start and register with your GitHub repo.

### Trigger a build

1. Go to Actions tab in GitHub
2. Select "Deploy NixOS Configuration"
3. Click "Run workflow"
4. Select your target machine and click "Run workflow"

