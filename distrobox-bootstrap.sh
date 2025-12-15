#!/bin/bash
# Bootstrap script for distrobox development environment
# Synced with cluster/common/home.nix
#
# IMPORTANT: When updating cluster/common/home.nix, also update the dnf install commands below
# to keep Fedora/distrobox environment in sync with your NixOS configuration.
#
# Run this inside the distrobox container after entering it
#
# First-time setup (run on host):
#   mkdir -p ~/distrobox-homes/fedora-dev
#   distrobox-create --name fedora-dev --image registry.fedoraproject.org/fedora-toolbox:43 --home ~/distrobox-homes/fedora-dev
#   distrobox enter fedora-dev
#
# Then run this script inside the distrobox:
#   ./distrobox-bootstrap.sh

set -e

echo "🚀 Starting distrobox bootstrap..."

# Install all packages from home.nix (mapped to Fedora equivalents)
echo "📦 Installing development tools via dnf..."
sudo dnf install -y \
    fastfetch \
    tmux \
    pigz \
    pixz \
    htop \
    graphviz \
    cloc \
    openssl \
    tree \
    yamllint \
    jq \
    git \
    vim \
    neovim \
    wget \
    curl \
    coreutils \
    gcc \
    gcc-c++ \
    cmake \
    make \
    binutils \
    bc \
    file \
    protobuf \
    protobuf-compiler \
    python3 \
    python3-pip \
    nodejs \
    npm \
    php \
    php-cli \
    php-mysqli \
    ripgrep \
    fd-find \
    unzip \
    azure-cli \
    util-linux-user \
    zsh \
    code

echo "📝 Syncing with home.nix packages..."

# Install Go (go_1_24 in home.nix)
echo "🐹 Installing Go..."
if ! command -v go &> /dev/null; then
    sudo dnf install -y golang
fi

echo "🐙 Installing GitHub CLI..."
if ! command -v gh &> /dev/null; then
    sudo dnf install -y 'dnf-command(config-manager)'
    sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
    sudo dnf install -y gh
fi

# Install kubectl
echo "☸️  Installing kubectl..."
if ! command -v kubectl &> /dev/null; then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
fi

# Install kubectx and kubens
echo "☸️  Installing kubectx..."
if ! command -v kubectx &> /dev/null; then
    sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
    sudo ln -sf /opt/kubectx/kubectx /usr/local/bin/kubectx
    sudo ln -sf /opt/kubectx/kubens /usr/local/bin/kubens
fi

# Install k9s
echo "🐶 Installing k9s..."
if ! command -v k9s &> /dev/null; then
    K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | jq -r .tag_name)
    curl -L "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz" | tar xz -C /tmp
    sudo mv /tmp/k9s /usr/local/bin/
fi

# Install lazygit
echo "😴 Installing lazygit..."
if ! command -v lazygit &> /dev/null; then
    sudo dnf copr enable -y atim/lazygit
    sudo dnf install -y lazygit
fi

# Install Helm
echo "⎈ Installing Helm..."
if ! command -v helm &> /dev/null; then
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Install Helmfile
echo "⎈ Installing Helmfile..."
if ! command -v helmfile &> /dev/null; then
    HELMFILE_VERSION=$(curl -s https://api.github.com/repos/helmfile/helmfile/releases/latest | jq -r .tag_name)
    curl -L "https://github.com/helmfile/helmfile/releases/download/${HELMFILE_VERSION}/helmfile_${HELMFILE_VERSION#v}_linux_amd64.tar.gz" | tar xz -C /tmp
    sudo mv /tmp/helmfile /usr/local/bin/
fi

# Install kustomize
echo "☸️  Installing kustomize..."
if ! command -v kustomize &> /dev/null; then
    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
    sudo mv kustomize /usr/local/bin/
fi

# Install Flux CLI
echo "🔄 Installing Flux CLI..."
if ! command -v flux &> /dev/null; then
    curl -s https://fluxcd.io/install.sh | sudo bash
fi

# Install eksctl
echo "☁️  Installing eksctl..."
if ! command -v eksctl &> /dev/null; then
    ARCH=amd64
    PLATFORM=$(uname -s)_$ARCH
    curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"
    tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp
    sudo mv /tmp/eksctl /usr/local/bin
    rm eksctl_$PLATFORM.tar.gz
fi

# Install Terraform
echo "🏗️  Installing Terraform..."
if ! command -v terraform &> /dev/null; then
    sudo dnf install -y dnf-plugins-core
    sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
    sudo dnf install -y terraform
fi

# Install AWS CLI
echo "☁️  Installing AWS CLI..."
if ! command -v aws &> /dev/null; then
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
    unzip -q /tmp/awscliv2.zip -d /tmp
    sudo /tmp/aws/install
    rm -rf /tmp/aws /tmp/awscliv2.zip
fi

# Install Azure CLI
echo "☁️  Installing Azure CLI..."
if ! command -v az &> /dev/null; then
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    sudo dnf install -y https://packages.microsoft.com/config/rhel/9.0/packages-microsoft-prod.rpm
    sudo dnf install -y azure-cli
fi

# Install Rust
echo "🦀 Installing Rust..."
if ! command -v rustup &> /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
fi

# Install Go tools (golangci-lint, go-migrate from home.nix)
echo "🐹 Installing Go tools..."
export PATH=$PATH:$(go env GOPATH)/bin
if ! command -v golangci-lint &> /dev/null; then
    go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
fi
if ! command -v migrate &> /dev/null; then
    go install -tags 'mysql postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest
fi

# Install act (GitHub Actions local runner)
echo "🎬 Installing act..."
if ! command -v act &> /dev/null; then
    curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash
fi

# Install Tilt
echo "🔧 Installing Tilt..."
if ! command -v tilt &> /dev/null; then
    curl -fsSL https://raw.githubusercontent.com/tilt-dev/tilt/master/scripts/install.sh | bash
fi

# Install Cursor (from cursor.nix in home.nix)
# Can be exported to host with: distrobox-export --app cursor
echo "💻 Installing Cursor..."
if ! command -v cursor &> /dev/null; then
    CURSOR_VERSION="2.2.20"
    CURSOR_URL="https://downloads.cursor.com/production/b3573281c4775bfc6bba466bf6563d3d498d1074/linux/x64/Cursor-${CURSOR_VERSION}-x86_64.AppImage"
    CURSOR_PATH="/tmp/cursor.AppImage"
    
    echo "Downloading Cursor ${CURSOR_VERSION}..."
    curl -L "${CURSOR_URL}" -o "${CURSOR_PATH}"
    chmod +x "${CURSOR_PATH}"
    
    # Install AppImage support
    sudo dnf install -y fuse2 libfuse2
    
    # Create wrapper script
    sudo tee /usr/local/bin/cursor > /dev/null << 'CURSOR_WRAPPER'
#!/bin/bash
exec /tmp/cursor.AppImage "$@"
CURSOR_WRAPPER
    sudo chmod +x /usr/local/bin/cursor
    
    echo "✅ Cursor installed. Use 'distrobox-export --app cursor' to expose on host."
fi

# Install ngrok
echo "🌐 Installing ngrok..."
if ! command -v ngrok &> /dev/null; then
    curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/pki/rpm-gpg/RPM-GPG-KEY-ngrok > /dev/null
    cat << 'REPO' | sudo tee /etc/yum.repos.d/ngrok.repo
[ngrok]
name=ngrok
baseurl=https://ngrok-agent.s3.amazonaws.com/rpm
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-ngrok
REPO
    sudo dnf install -y ngrok
fi

# Set up zsh as default shell
echo "🐚 Setting up zsh..."
if [ "$SHELL" != "/bin/zsh" ]; then
    chsh -s /bin/zsh
fi

# Install oh-my-zsh if not already installed
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing oh-my-zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Install powerlevel10k theme
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
    echo "Installing powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
fi

# Install zsh plugins
echo "🔌 Installing zsh plugins..."
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
fi
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
fi

# Configure git
echo "⚙️  Configuring git..."
git config --global user.email "jasonkwh@gmail.com"
git config --global user.name "Jason Huang"

# Create .npmrc
echo "📦 Configuring npm..."
mkdir -p ~/.npm-global
cat > ~/.npmrc << 'EOF'
prefix=${HOME}/.npm-global
EOF

# Configure .zshrc
echo "⚙️  Configuring .zshrc..."
cat > ~/.zshrc << 'EOF'
# Path to oh-my-zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

# Aliases (from home.nix)
alias ll="ls -lh --color=auto"
alias kc="kubectl"
alias python="python3"
alias vi="nvim"
alias neofetch="fastfetch"

# PATH (from home.nix initContent)
export PATH=$PATH:$(go env GOPATH)/bin:$HOME/.npm-global/bin

# Environment variables
export EDITOR="vim"
export KUBECONFIG="$HOME/.kube/config"

# Load p10k config if exists
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
EOF

# Export GUI applications to host
echo "📦 Exporting GUI applications to host..."
if command -v distrobox-export &> /dev/null; then
    distrobox-export --app code 2>/dev/null || echo "  ⚠️  Could not export VS Code (may not be in distrobox)"
    distrobox-export --app cursor 2>/dev/null || echo "  ⚠️  Could not export Cursor (may not be in distrobox)"
else
    echo "  ⚠️  distrobox-export not available (run this inside distrobox)"
fi

echo ""
echo "✅ Bootstrap complete!"
echo ""
echo "Next steps:"
echo "1. Restart your shell or run: exec zsh"
echo "2. Then run 'p10k configure' to set up powerlevel10k theme"
echo ""
echo "📦 For GUI apps on the host:"
echo "   distrobox-export --app code      # Exports VS Code"
echo "   distrobox-export --app cursor    # Exports Cursor"
echo ""
echo "📝 This bootstrap syncs packages from: cluster/common/home.nix"
