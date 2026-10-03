# Fleet Syncthing settings. NixOS runs this as the hermes user; SteamOS
# runs it as the login user. Only the folder paths differ.
{ syncthingDevices, tailscaleDomain, folderPaths }:

let
  allDevices = builtins.attrNames syncthingDevices;
  folderVersioning = {
    type = "trashcan";
    fsType = "simple";
    params.cleanoutDays = "14";
  };
  folder = name: {
    path = folderPaths.${name};
    devices = allDevices;
    versioning = folderVersioning;
    ignorePerms = true;
  };
in
{
  options = {
    # Fleet is always behind Tailscale; no need for global
    # discovery/relay/NAT traversal.
    globalAnnounceEnabled = false;
    localAnnounceEnabled = true;
    relaysEnabled = false;
    natEnabled = false;
    urAccepted = -1;
  };
  # Pin peers by MagicDNS name (not raw 100.x IPs — those can change).
  # "dynamic" discovery alone is not enough: local broadcast doesn't
  # cross the Tailscale interface and global announce is disabled.
  devices = builtins.mapAttrs
    (name: dev:
      dev // {
        addresses = [ "tcp://${name}.${tailscaleDomain}:22000" ];
      })
    syncthingDevices;
  folders = {
    hermes-memories = folder "hermes-memories";
    hermes-skills = folder "hermes-skills";
  };
}
