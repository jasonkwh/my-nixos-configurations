{ config, pkgs, ... }:

{
  # Install Gemini CLI globally via npm to ~/.npm-global
  home.activation.installGeminiCli = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    PATH="${pkgs.nodejs_24}/bin:$PATH"
    export npm_config_prefix="${config.home.homeDirectory}/.npm-global"
    
    if ! ${pkgs.nodejs_24}/bin/npm list -g @google/gemini-cli 2>/dev/null | grep -q @google/gemini-cli; then
      echo "Installing @google/gemini-cli..."
      ${pkgs.nodejs_24}/bin/npm install -g @google/gemini-cli@latest
    fi
  '';
}
