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

