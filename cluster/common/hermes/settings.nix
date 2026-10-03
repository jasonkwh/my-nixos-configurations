# Shared Hermes agent configuration. The NixOS service and the SteamOS
# home-manager module both consume this; only the service wrapper differs.
{
  lib,
  pkgs,
  hermesModel,
  hermesPeerHosts,
  tailscaleDomain,
  hostName,
  homeDirectory,
  isFleetHub ? false,
  # Tailnet peers dial this host by name. The default API server binds
  # localhost, which those peers cannot reach.
  bindApiServer ? false,
}:

{
  extraDependencyGroups = [ "messaging" ];
  extraPackages = with pkgs; [
    git
    ripgrep
    fd
    file
    himalaya
  ];
  environment = {
    WHATSAPP_HOME_CHANNEL_NAME = "Jason's ShengOS";
    WHATSAPP_MODE = "self-chat";
    HIMALAYA_CONFIG = "${homeDirectory}/.config/himalaya/config.toml";
    HERMES_MACHINE_IDENTITY = "xiaoshengsheng @ ${hostName}";
  };
  environmentFiles = [ "${homeDirectory}/.secrets/hermes-env" ];
  settings = {
    # Schema version expected by the pinned Hermes Agent input.
    _config_version = 38;
    agent.api_max_retries = 6;
    model = hermesModel;
    memory = {
      memory_enabled = true;
      user_profile_enabled = true;
      write_approval = true;
    };
    compression = {
      enabled = true;
      threshold = 0.35;
      target_ratio = 0.15;
    };
    display.show_reasoning = false;
    terminal.backend = "local";
    web = {
      # Tavily key (TAVILY_API_KEY) is in hermes-env.
      search_backend = "tavily";
      extract_backend = "tavily";
    };
    browser = {
      cdp_url = "http://127.0.0.1:9222";
      backend = "off";
    };
    # Peer keys are HERMES_PEER_<NAME>_KEY in hermes-env.
    bot_peers = builtins.listToAttrs (map
      (host: lib.nameValuePair host {
        url = "http://${host}.${tailscaleDomain}:8642";
      })
      (lib.filter (h: h != hostName) hermesPeerHosts));
    # Always present. An omitted attr would drop the empty set that NixOS
    # laptops already write, and the hub's webhook would no longer match.
    platforms =
      lib.optionalAttrs bindApiServer {
        api_server = {
          enabled = true;
          extra = {
            host = "0.0.0.0";
            port = 8642;
          };
        };
      }
      // lib.optionalAttrs isFleetHub {
        # The gateway itself is host-specific (only one machine may hold the
        # WhatsApp session). The home channel is fleet-wide.
        webhook = {
          enabled = true;
          extra = {
            host = "127.0.0.1";
            port = 8644;
            routes.alertmanager = {
              secret = "INSECURE_NO_AUTH";
              prompt = ''
                [{status}] {commonLabels.alertname} ({commonLabels.severity})
                {commonLabels.instance}
                {commonAnnotations.summary}
              '';
              deliver = "whatsapp";
              deliver_only = true;
            };
          };
        };
      };
  };
}
