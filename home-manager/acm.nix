# ACM-equivalent display colour management -- home-manager module.
#
# Runs the session daemon that keeps the ACM transform applied: it computes the
# transform from the panel profile and hands it to the compositor through
# wlr-gamma-control (which programs the CRTC's GAMMA_LUT), or -- when DRM
# master is available -- programs DEGAMMA_LUT + CTM + GAMMA_LUT directly.
#
# Declarative usage (in ~/.config/home-manager/home.nix):
#
#   imports = [ ./acm.nix ];
#   home.acm = {
#     enable = true;
#     displays."eDP-1" = { };
#     displays."HDMI-A-1" = { gamma = 1.05; temperatureEnabled = true; temperature = 6000; };
#   };
{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf mkOption mkEnableOption types;
  cfg = config.home.acm;

  displayType = types.submodule {
    options = {
      match = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Selector for the physical display.  Connector names such as "HDMI-A-1"
          are not stable across boots, so prefer a stable selector:
            hash:<16 hex>     SHA-256 of the EDID blob (most stable)
            id:<PNP><PROD>-<SERIAL>
            serial:<value>
            name:<monitor name>
            con:<connector>   volatile, but useful to disambiguate
          When null, the attribute name is used as the selector.  Run
          `acm-ctl list` to see the identifiers of the connected displays.
        '';
        example = "hash:4ce7d007462e9a2d";
      };
      enable = mkOption { type = types.bool; default = true; };
      mode = mkOption { type = types.enum [ "auto" "gamma" "kms" ]; default = "auto"; };
      profile = mkOption { type = types.nullOr types.path; default = null; };
      content = mkOption { type = types.enum [ "sRGB" "DisplayP3" "Rec2020" "scRGB" ]; default = "sRGB"; };
      brightness = mkOption { type = types.float; default = 1.0; };
      black = mkOption { type = types.float; default = 0.0; };
      gamma = mkOption { type = types.float; default = 1.0; };
      temperature = mkOption { type = types.int; default = 6500; };
      temperatureEnabled = mkOption { type = types.bool; default = false; };
      sdrWhite = mkOption { type = types.float; default = 1.0; };
    };
  };

  configText = lib.concatStrings (
    lib.mapAttrsToList (name: d:
      let
        key = if d.match != null then d.match else name;
      in
      ''
        [display "${key}"]
        enabled = ${if d.enable then "true" else "false"}
        mode = ${d.mode}
        profile = ${if d.profile == null then "" else toString d.profile}
        content = ${d.content}
        brightness = ${toString d.brightness}
        black = ${toString d.black}
        gamma = ${toString d.gamma}
        temperature = ${toString d.temperature}
        temperature-enabled = ${if d.temperatureEnabled then "true" else "false"}
        sdr-white = ${toString d.sdrWhite}

      '') cfg.displays)
    + ''
      [acm]
      reconcile-seconds = ${toString cfg.reconcileSeconds}
      tolerance = ${toString cfg.tolerance}
    '';
in
{
  options.home.acm = {
    enable = mkEnableOption "ACM-equivalent display colour management (session daemon)";

    package = mkOption {
      type = types.package;
      default = pkgs.callPackage /etc/nixos/acm/package.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage /etc/nixos/acm/package.nix { }";
    };

    displays = mkOption {
      type = types.attrsOf displayType;
      default = { };
      description = ''
        Per-display ACM configuration.  The attribute name is the selector used to
        find the display, unless `match` is set.  Prefer a stable selector such as
        `hash:...`, because connector names change between boots.  Run
        `acm-ctl list` to obtain the identifiers of the connected displays.
      '';
      example = lib.literalExpression ''
        {
          internal = { match = "hash:380c4f83604eae61"; };
          external = { match = "hash:4ce7d007462e9a2d"; temperatureEnabled = true; temperature = 6000; };
        }
      '';
    };

    reconcileSeconds = mkOption {
      type = types.int;
      default = 5;
      description = "How often the daemon checks that the transform is still programmed";
    };

    tolerance = mkOption {
      type = types.float;
      default = 1.0 / 255.0;
      description = "Accepted deviation between the desired and the programmed ramp";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.configFile."acm/displays.conf".text = configText;

    systemd.user.services.acm = {
      Unit = {
        Description = "ACM-equivalent display colour management";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
        ConditionEnvironment = "WAYLAND_DISPLAY";
      };
      Service = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/acm-ctl daemon --config %h/.config/acm/displays.conf --interval ${toString cfg.reconcileSeconds}";
        Restart = "always";
        RestartSec = 3;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
