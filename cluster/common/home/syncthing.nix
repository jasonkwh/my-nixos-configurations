# User-level Syncthing for SteamOS. The identity lives under the login
# user's state directory, and the folders are that user's HERMES_HOME.
{ syncthingDevices, tailscaleDomain, homeDirectory, ... }:

{
  services.syncthing = {
    enable = true;
    overrideDevices = true;
    overrideFolders = true;
    settings = import ../syncthing/settings.nix {
      inherit syncthingDevices tailscaleDomain;
      folderPaths = {
        hermes-memories = "${homeDirectory}/.hermes/memories";
        hermes-skills = "${homeDirectory}/.hermes/skills";
      };
    };
  };
}
