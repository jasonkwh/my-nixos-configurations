#!/bin/bash
# Bootstrap script for distrobox development environment
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

# Install development tools via dnf
echo "📦 Installing development tools via dnf..."
sudo dnf install -y \
    git \
    vim \
    neovim \
    wget \
    curl \
    gcc \
    gcc-c++ \
    cmake \
    make \
    htop \
    tmux \
    tree \
    zsh \
    util-linux-user \
    golang \
    nodejs \
    npm \
    python3 \
    python3-pip \
    php \
    php-mysqli \
    openssl \
    jq \
    ripgrep \
    fd-find \
    fastfetch \
    pigz \
    graphviz \
    cloc \
    yamllint \
    binutils \
    bc \
    file \
    protobuf \
    protobuf-compiler \
    unzip

# Install GitHub CLI
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

# Install Go tools
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

# Aliases
alias ll="ls -lh --color=auto"
alias kc="kubectl"
alias python="python3"
alias vi="nvim"
alias neofetch="fastfetch"

# PATH
export PATH="$HOME/.local/bin:$HOME/go/bin:$HOME/.npm-global/bin:$HOME/.cargo/bin:$PATH"

# Environment variables
export EDITOR="vim"
export KUBECONFIG="$HOME/.kube/config"

# Load p10k config if exists
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
EOF

echo ""
echo "✅ Bootstrap complete!"
echo ""
echo "Please restart your shell or run: exec zsh"
echo "Then run 'p10k configure' to set up powerlevel10k theme."
