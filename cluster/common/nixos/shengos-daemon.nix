{ name, ... }:

{
  environment.etc."shengos-daemon/config.yaml".source = ./../../${name}/daemon.yaml;

  services.shengos-daemon = {
    enable = true;
    configFile = "/etc/shengos-daemon/config.yaml";
  };
}
