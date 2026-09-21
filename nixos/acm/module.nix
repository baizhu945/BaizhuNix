# ACM-equivalent display colour management -- NixOS module.
#
# Provides the `acm-ctl` tool and (optionally) a system-level daemon that
# programs the display pipeline through DRM/KMS.  The user-facing daemon (which
# works under a Wayland compositor via wlr-gamma-control) is provided by the
# matching home-manager module, because it needs the user's session.
#
# Declarative usage (in /etc/nixos/configuration.nix):
#
#   imports = [ ./acm/module.nix ];
#   services.acm = {
#     enable = true;
#     displays."eDP-1" = { mode = "auto"; };
#     displays."HDMI-A-1" = { mode = "auto"; temperatureEnabled = true; temperature = 6000; };
#   };
{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf mkOption mkEnableOption mkDefault types;
  cfg = config.services.acm;

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
      mode = mkOption {
        type = types.enum [ "auto" "gamma" "kms" ];
        default = "auto";
        description = "gamma = compositor ramp (works under any compositor), kms = full degamma+CTM+regamma (needs DRM master)";
      };
      profile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "ICC profile path; null derives the profile from the panel EDID";
      };
      content = mkOption {
        type = types.enum [ "sRGB" "DisplayP3" "Rec2020" "scRGB" ];
        default = "sRGB";
      };
      brightness = mkOption { type = types.float; default = 1.0; };
      black = mkOption { type = types.float; default = 0.0; };
      gamma = mkOption { type = types.float; default = 1.0; };
      temperature = mkOption { type = types.int; default = 6500; };
      temperatureEnabled = mkOption { type = types.bool; default = false; };
      sdrWhite = mkOption {
        type = types.float;
        default = 1.0;
        description = "SDR reference-white scale (the ACM white-level equivalent)";
      };
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
  options.services.acm = {
    enable = mkEnableOption "ACM-equivalent automatic display colour management";

    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ./package.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage ./package.nix { }";
      description = "The acm-ctl package (colour engine + KMS/Wayland appliers)";
    };

    user = mkOption {
      type = types.str;
      default = "<yourusername>";
      description = "User that runs the session daemon and gets DRM device access";
    };

    addVideoGroup = mkOption {
      type = types.bool;
      default = true;
      description = "Add `user` to the video group so /dev/dri is always accessible (not only via the logind ACL)";
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

    reconcileSeconds = mkOption { type = types.int; default = 5; };
    tolerance = mkOption { type = types.float; default = 1.0 / 255.0; };

    loadVkms = mkOption {
      type = types.bool;
      default = false;
      description = "Load the vkms virtual KMS driver (used by `acm-ctl selftest` on machines without a free display)";
    };

    systemService = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Also run a system-level acm-ctl daemon.  Useful on a KMS-only/console
        session; under a Wayland compositor the compositor owns DRM master, so
        the user-level (home-manager) daemon with the gamma applier is used
        instead.
      '';
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    environment.etc."acm/displays.conf".text = configText;

    # DRM access for the session daemon.  logind already grants an ACL to the
    # active session; group membership makes it unconditional.
    users.groups.video.members = mkIf cfg.addVideoGroup [ cfg.user ];

    boot.kernelModules = mkIf cfg.loadVkms [ "vkms" ];

    systemd.services.acm = mkIf cfg.systemService {
      description = "ACM-equivalent display colour management (system daemon)";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-udev-settle.service" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/acm-ctl daemon --config /etc/acm/displays.conf --interval ${toString cfg.reconcileSeconds}";
        Restart = "on-failure";
        RestartSec = 3;
        User = "root";
      };
    };
  };
}
