# Bake the fleet secrets into the SD-card image at build time.
#
# Imported via image.modules.sd-card (see cluster/bcm2711/configuration.nix)
# so the sdImage options only exist inside the SD-image variant — the plain
# system toplevel never sees them.
#
# `make image` (Makefile) sets SECRETS_SRC to the build host's ~/.secrets;
# that path is read at EVAL time and the directory is copied into the image's
# root filesystem, so a freshly flashed board boots with working Wi-Fi
# (headless-env) and Hermes keys (hermes-env) already in place — no
# post-flash rsync step. Without SECRETS_SRC the module is inert.
{
  lib,
  username,
  ...
}:

let
  secretsSrc = builtins.getEnv "SECRETS_SRC";
in
{
  sdImage.populateRootCommands = lib.mkIf (secretsSrc != "") (lib.mkAfter ''
    mkdir -p ./files/home/${username}/.secrets
    cp -a ${secretsSrc}/. ./files/home/${username}/.secrets/
    chown -R 1000:100 ./files/home/${username}/.secrets
    chmod 700 ./files/home/${username}/.secrets
    chmod 600 ./files/home/${username}/.secrets/* 2>/dev/null || true
    echo "sd-image: secrets baked into /home/${username}/.secrets"
  '');
}
