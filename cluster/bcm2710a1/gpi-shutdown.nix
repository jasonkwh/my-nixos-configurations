# RetroFlag GPi Case safe-shutdown (BCM2710A1 cartridge).
# Source: https://github.com/RetroFlag/retroflag-picase — RetroFlag_pw_io.dtbo
# + SafeShutdown_gpi.py, translated to NixOS:
#   - GPIO27 is the power-hold line: driven HIGH at boot, dropping it cuts power.
#   - GPIO26 is the power button: held ~1s -> systemctl poweroff.
# Official script kills emulationstation then reboots; we power off instead and
# avoid a resident Python process (gpiozero) on the 512MB board.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Vendored verbatim from RetroFlag/retroflag-picase (upstream is stable;
  # re-fetching at build time would make builds depend on GitHub uptime).
  gpiOverlay = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/RetroFlag/retroflag-picase/master/RetroFlag_pw_io.dtbo";
    hash = "";
  };
in
{
  # Apply the vendor overlay via the device tree (config.txt dtoverlay=... is
  # handled by this same mechanism on Pi boards).
  hardware.deviceTree.overlays = [
    {
      name = "retroflag-pw-io.dtbo";
      dtboFile = gpiOverlay;
    }
  ];

  systemd.services.gpi-safe-shutdown = {
    description = "GPi Case power button (GPIO26 long-press -> poweroff) + power-hold (GPIO27)";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
    };
    script = ''
      # GPIO27 high = power held. This must be raised ASAP; if this service is
      # slow to start the board may already be losing power — the overlay
      # cannot pre-configure output levels, so boot-time gap is inherent to
      # the GPi design (same as the official rc.local-based script).
      ${pkgs.libgpiod}/bin/gpioset -m signal `# wait forever` \
        gpiochip0 27=1 26=0 \
        --daemonize 2>/dev/null || true

      # Watch GPIO26; 1s press triggers clean shutdown.
      exec ${pkgs.libgpiod}/bin/gpiomon --num-events=1 --falling-edge \
        --handler='
        if [ "$GPIOD_CTX_LINE_EVENT_LINE_VALUES" = "1" ]; then
          sleep 1
          if [ "$(${pkgs.libgpiod}/bin/gpioget gpiochip0 26)" = "1" ]; then
            systemctl poweroff
          fi
        fi
      ' gpiochip0 26
    '';
  };
}
