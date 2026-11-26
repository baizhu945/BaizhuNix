{ config, lib, pkgs, ... }:

let
  player = pkgs.callPackage ./package.nix { };
  assets = pkgs.callPackage ./assets.nix { };
  screens = {
    "eDP-1" = { character = "chocola/date-a"; background = "BG_07A"; mute = false; };
    "HDMI-A-1" = { character = "vanilla/date-a"; background = "BG_01"; mute = true; };
  };
  makeService = output: prefs:
    let
      name = "nekomote-${output}";
      stateDir = config.xdg.configHome + "/nekomote";
      state = "${stateDir}/${output}.panel.json";
      seed = pkgs.writeText "${name}-initial-panel.json" (builtins.toJSON (prefs // {
        version = 1;
        language = "zh-CN";
        fps = 30;
        fit = true;
      }));
      launch = pkgs.writeShellScript name ''
        set -eu
        player=${lib.getExe player}
        output=${lib.escapeShellArg output}
        state=${lib.escapeShellArg state}
        # A disconnected HDMI at login is normal. Wait without allocating a GPU
        # context; after the first bind the client handles hotplug by itself.
        connected() {
          "$player" --list-outputs 2>/dev/null | ${pkgs.gnugrep}/bin/grep -Fxq -- "$output"
        }
        if ! connected; then
          echo "Waiting for Wayland output $output"
          until connected; do ${pkgs.coreutils}/bin/sleep 10; done
        fi
        # Seed a writable preference file once; keep later in-panel edits.
        ${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg stateDir}
        if [ ! -e "$state" ]; then
          ${pkgs.coreutils}/bin/install -m 600 ${seed} "$state"
        fi
        exec "$player" --assets ${assets}/assets --output "$output" \
          --backend opengl --input interactive --gaze desktop --state "$state" \
          --config ${lib.escapeShellArg "${stateDir}/${output}.json"}
      '';
    in lib.nameValuePair name {
      Unit = {
        Description = "NekoMote interactive wallpaper on ${output}";
        After = [ "niri.service" ];
        PartOf = [ "niri.service" ];
        StartLimitIntervalSec = 90;
        StartLimitBurst = 5;
      };
      Service = {
        Type = "simple";
        ExecStart = "${launch}";
        Restart = "on-failure";
        RestartSec = "5s";
        Slice = "session.slice";
      };
      Install.WantedBy = [ "niri.service" ];
    };
in {
  home.packages = [ player ];
  xdg.dataFile."nekomote/assets".source = "${assets}/assets";
  # systemd.user.services = lib.mapAttrs' makeService screens;
}
