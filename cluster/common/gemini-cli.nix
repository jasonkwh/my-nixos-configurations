{ config, pkgs, ... }:

{
  # Install Gemini CLI globally via npm to ~/.npm-global
  home.activation.installGeminiCli = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    PATH="${pkgs.nodejs_24}/bin:$PATH"
    export npm_config_prefix="${config.home.homeDirectory}/.npm-global"
    
    echo "Installing @google/gemini-cli..."
    ${pkgs.nodejs_24}/bin/npm uninstall -g @google/gemini-cli 2>/dev/null || true
    ${pkgs.nodejs_24}/bin/npm cache clean --force 2>/dev/null || true
    ${pkgs.nodejs_24}/bin/npm install -g @google/gemini-cli@latest --force
  '';
}
