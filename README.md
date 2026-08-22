<p align="center">
  <img src="assets/logos/logo.png" alt="ShengOS logo" width="180">
</p>

<h1 align="center">ShengOS</h1>

<p align="center">
  My personal, reproducible Linux environment built on top of NixOS.
</p>

It is not a separate Linux distribution in the traditional sense—with its own installer and package repositories—but a carefully assembled personal operating system. The configuration defines the system, desktop, applications, development tools, services, security settings, and user environment as code. Rebuilding the flake turns that definition into a complete NixOS system generation that can be upgraded, reproduced, or rolled back safely.

ShengOS currently supports two laptop profiles:

- **jasonkwh-7520u** — AMD Ryzen-based laptop with AMD graphics, Steam, gaming optimisations, and hibernation support.
- **jasonkwh-7300u** — Intel-based laptop with its own graphics, thermal, and power-management settings.

Both machines share a common foundation while retaining hardware-specific configuration where necessary. The environment includes KDE Plasma, Home Manager, Chinese Pinyin input, developer tooling, containers, cloud and Kubernetes utilities, Hermes Agent, Tailscale, and other services I use every day.

## Update the OS

To update the flake inputs and rebuild the system, run these commands from anywhere:

```bash
meow update
meow upgrade
```

`meow update` updates the NixOS flake inputs, while `meow upgrade` rebuilds and activates the configuration for the current hostname.

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
   make build jasonkwh-7520u
   ```

The runner will automatically start and register with your GitHub repo.

### Trigger a build

1. Go to Actions tab in GitHub
2. Select "Deploy NixOS Configuration"
3. Click "Run workflow"
4. Select your target machine and click "Run workflow"

