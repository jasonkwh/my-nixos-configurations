# Desktop applications and user config. Imported for every !isHeadless host,
# including SteamOS. Plasma itself lives in plasma.nix.
{
  config,
  osConfig ? null,
  pkgs,
  lib,
  ...
}:

let
  # NixOS Hermes is a system service. On SteamOS it is the user service.
  enableHermes =
    if builtins.isAttrs osConfig
    then osConfig.services.hermes-agent.enable or false
    else (config.services.hermes-agent or { }).enable or false;
in
{
  # Skip Cursor's Sentry crash-reporter and Electron GPU crashes.
  home.file.".config/Cursor/argv.json".text = builtins.toJSON {
    "disable-hardware-acceleration" = true;
    "enable-crash-reporter" = false;
    "enable-proposed-api" = [];
  };

  # QtMultimedia dlopens libpipewire-0.3, invisible on NixOS; harmless noise.
  home.file.".config/QtProject/qtlogging.ini".text = ''
    [Rules]
    qt.multimedia.symbolsresolver=false
  '';

  home.file.".config/kwalletrc".text = ''
    [org.freedesktop.secrets]
    apiEnabled=true
  '';

  xdg.autostart.enable = true;

  programs.thunderbird = {
    enable = true;
    profiles.default.isDefault = true;
  };

  accounts.email.accounts.gmail = lib.mkIf enableHermes {
    thunderbird.enable = true;
    thunderbird.settings = id: {
      "mail.server.server_${id}.offline_download" = false;
      "mail.server.server_${id}.autosync_offline_stores" = false;
    };
  };

  # Desktop-only packages: k8s/cloud/dev toolchains and language stacks
  # live here (not cli.nix) so ARM SD images stay lean.
  home.packages = with pkgs;
    [
      kubectl
      kubectx
      k9s
      kubelogin
      kustomize
      grpc
      act
      eksctl
      azure-cli
      awscli2
      ssm-session-manager-plugin
      awsebcli
      terraform
      kubernetes-helm
      helmfile
      pigz
      pixz
      graphviz
      lazygit
      cloc
      yamllint
      img2pdf
      go_1_26
      protobuf
      rustup
      python3
      php84
      php84Extensions.mysqli
      php84Extensions.grpc
      php84Extensions.protobuf
      php84Packages.composer
      tilt
      libreoffice-qt
      zoom-us
      brave
      sparrow
      code-cursor
      buildah
      skopeo
      ollama
      podman-compose
      kdePackages.isoimagewriter
      feather
    ];

  # Aliases ride along with the tools they point at (zsh is configured
  # in cli.nix).
  programs.zsh.shellAliases = lib.mkIf config.programs.zsh.enable {
    kc = "kubectl";
    python = "python3";
  };

  home.activation.podmanMigrate = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    if command -v podman &> /dev/null; then
      ${pkgs.podman}/bin/podman system migrate 2>/dev/null || true
    fi
  '';
}
