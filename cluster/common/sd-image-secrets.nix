# Bake the fleet secrets into the SD-card image at build time.
#
# Imported via image.modules.sd-card (see cluster/bcm2711/configuration.nix)
# so the sdImage options only exist inside the SD-image variant — the plain
# system toplevel never sees them.
#
# `make image` (Makefile) prompts once for the machine password and sets:
#   SECRETS_ENC   — ~/.secrets sealed with that password (AES-256)
#   SECRETS_PASS  — the same password (eval-time, for decrypt + hashing)
#   REPO_GIT_ARCHIVE — .git metadata omitted by Nix's flake source filtering
# Populate time then:
#   - decrypts the seal into /home/<username>/.secrets
#   - bakes the repo bundle into ~/Documents/my-nixos-configurations
#   - sets jasonkwh's AND root's login password (yescrypt, via
#     users.users.<>.hashedPassword — native NixOS, survives rebuilds)
# Without SECRETS_ENC the module is inert (legacy plaintext SECRETS_SRC
# fallback kept, deprecated; no password is set in that mode).
{
  lib,
  pkgs,
  username,
  ...
}:

let
  secretsEnc = builtins.getEnv "SECRETS_ENC";
  secretsPass = builtins.getEnv "SECRETS_PASS";
  secretsSrc = builtins.getEnv "SECRETS_SRC";
  repoGitArchive = builtins.getEnv "REPO_GIT_ARCHIVE";

  # getEnv returns a context-free string. Restore store-path context so this
  # file is a declared derivation input and is copied to remote builders.
  secretsEncPath =
    if secretsEnc != "" then builtins.storePath secretsEnc else null;
  repoGitArchivePath =
    if repoGitArchive != "" then builtins.storePath repoGitArchive else null;

  repoBundle = pkgs.runCommand "my-nixos-configurations-bundle" { } ''
    mkdir -p "$out/share"
    cp -R ${../..} "$out/share/my-nixos-configurations"
    chmod -R u+rwX,go+rX "$out/share/my-nixos-configurations"
  '';

  # yescrypt hash of the machine password, computed at EVAL time from the
  # SECRETS_PASS env var. mkpasswd (shadow) generates a random salt each
  # call — fine, the store path just changes when the password changes.
  passHash = if secretsPass != ""
    then
      let
        raw = builtins.readFile (pkgs.runCommand "machine-pass-hash" { } ''
          ${lib.getExe' pkgs.mkpasswd "mkpasswd"} -m yescrypt ${lib.escapeShellArg secretsPass} > "$out"
        '');
      in
      # strip the trailing newline readFile captures (option type forbids them)
      lib.removeSuffix "\n" raw
    else "";

  secretsSetup = lib.optionalString (secretsEnc != "") ''
    mkdir -p ./files/home/${username}/.secrets
    SECRETS_PASS=${lib.escapeShellArg secretsPass} \
      ${lib.getExe' pkgs.openssl "openssl"} enc -d -aes-256-cbc -pbkdf2 -iter 600000 \
      -in ${secretsEncPath} -out ./files/.secrets.tar -pass env:SECRETS_PASS
    tar -xf ./files/.secrets.tar -C ./files/home/${username}/.secrets
    rm -f ./files/.secrets.tar
    chown -R 1000:100 ./files/home/${username}/.secrets
    chmod 700 ./files/home/${username}/.secrets
    chmod 600 ./files/home/${username}/.secrets/* 2>/dev/null || true
    echo "sd-image: secrets baked into /home/${username}/.secrets"

  '';

  repoSetup = lib.optionalString (repoGitArchive != "") ''
    mkdir -p ./files/home/${username}/Documents
    cp -R ${repoBundle}/share/my-nixos-configurations ./files/home/${username}/Documents/
    tar -xf ${repoGitArchivePath} \
      -C ./files/home/${username}/Documents/my-nixos-configurations
    chown -R 1000:100 ./files/home/${username}/Documents/my-nixos-configurations
    chmod -R u+rwX,go+rX ./files/home/${username}/Documents/my-nixos-configurations
    echo "sd-image: git repo baked into /home/${username}/Documents/my-nixos-configurations"
  '';

  legacyPlaintext = lib.optionalString (secretsEnc == "" && secretsSrc != "") ''
    mkdir -p ./files/home/${username}/.secrets
    cp -a ${secretsSrc}/. ./files/home/${username}/.secrets/
    chown -R 1000:100 ./files/home/${username}/.secrets
    chmod 700 ./files/home/${username}/.secrets
    chmod 600 ./files/home/${username}/.secrets/* 2>/dev/null || true
    echo "sd-image: (plaintext) secrets baked into /home/${username}/.secrets"
  '';
in
{
  sdImage.populateRootCommands = lib.mkIf (secretsEnc != "" || secretsSrc != "" || repoGitArchive != "") (lib.mkAfter ''
    ${secretsSetup}
    ${repoSetup}
    ${legacyPlaintext}
  '');

  # Machine password = login password for both jasonkwh and root.
  users.users.${username}.hashedPassword = lib.mkIf (passHash != "") passHash;
  users.users.root.hashedPassword = lib.mkIf (passHash != "") passHash;
}