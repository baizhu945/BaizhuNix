{ pkgs, ... }:

let
  # Pin the complete nixpkgs package set that provides Noctalia 5.1.0 instead
  # of fetching Noctalia's source directly. Channel updates cannot move the
  # package or its dependencies underneath the source patches below.
  noctaliaNixpkgsTarball = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/c7def046b9a883d46974757852106483d741586f.tar.gz";
    sha256 = "sha256-6RSEDHIWQtesQKWSu5qRai8L2h4KgCgMEfJHstW99G4=";
  };
  noctaliaPkgs = import noctaliaNixpkgsTarball {
    config = {
      allowUnfree = true;
      allowInsecure = true;
    };
    system = pkgs.stdenv.hostPlatform.system;
  };

  # Source-level V4 compatibility changes live as single-purpose patch scripts
  # under patches/. Keep this derivation declarative and limited to applying
  # them in dependency order.
  noctalia = noctaliaPkgs.noctalia.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ noctaliaPkgs.python3 ];
    postPatch = (old.postPatch or "") + ''
      python3 ${./patches/patch-media-mini.py}
      python3 ${./patches/patch-stable-output.py}
      python3 ${./patches/patch-transparent-bar-blur.py}
      python3 ${./patches/patch-screenshot-secondary-click.py}
      python3 ${./patches/patch-panel-prewarm-blur.py}
      python3 ${./patches/patch-icon-raster-quality.py}
      python3 ${./patches/patch-brightness-fallback.py}
      python3 ${./patches/patch-panel-click-anchor.py}
      python3 ${./patches/patch-panel-background-opacity.py}
      python3 ${./patches/patch-panel-compositor-blur.py}
      python3 ${./patches/patch-icon-theme-environment.py}
      python3 ${./patches/patch-notification-timeouts.py}
      python3 ${./patches/patch-deskvis-renderer.py}
      python3 ${./patches/patch-deskvis-smoothing.py}
      python3 ${./patches/patch-deskvis-idle-fade.py}
      python3 ${./patches/patch-spectrum-frequency-range.py}
      python3 ${./patches/patch-osd-timeout.py}
      python3 ${./patches/patch-taskbar-title-color.py}
    '';
  });

  # The upstream Home Manager module validates config.toml in an isolated build
  # environment. A path plugin source under ~/.config is therefore unavailable
  # there, so otherwise every local widget is reported as unknown. Stage the
  # exact declarative plugin tree in a temporary HOME and validate against it.
  localPluginSources = {
    "catwalk-v5" = ./noctalia-v5-plugins/catwalk-v5;
    "media-mini-v5" = ./noctalia-v5-plugins/media-mini-v5;
    "network-monitor-v5" = ./noctalia-v5-plugins/network-monitor-v5;
    "showmethekey-v5" = ./noctalia-v5-plugins/showmethekey-v5;
    "todo-v5" = ./noctalia-v5-plugins/todo-v5;
    "keybind-cheatsheet-v5" = ./noctalia-v5-plugins/keybind-cheatsheet-v5;
    "screen-toolkit-v5" = ./noctalia-v5-plugins/screen-toolkit-v5;
    "supergfxctl-v5" = ./noctalia-v5-plugins/supergfxctl-v5;
    "v4-extras-v5" = ./noctalia-v5-plugins/v4-extras-v5;
    "screen-recorder-v5" = ./noctalia-v5-plugins/screen-recorder-v5;
    "bottom-bar-v5" = ./noctalia-v5-plugins/bottom-bar-v5;
  };
  localPluginTree = pkgs.linkFarm "noctalia-v5-local-plugins" (
    pkgs.lib.mapAttrsToList (name: path: { inherit name path; }) localPluginSources
  );
  validatedConfig = pkgs.runCommand "noctalia-config.toml" { } ''
    export HOME="$TMPDIR/home"
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_DATA_HOME="$HOME/.local/share"
    export XDG_STATE_HOME="$HOME/.local/state"
    export XDG_CACHE_HOME="$HOME/.cache"
    export XDG_RUNTIME_DIR="$TMPDIR/runtime"
    mkdir -p \
      "$XDG_CONFIG_HOME/noctalia" \
      "$XDG_DATA_HOME" \
      "$XDG_STATE_HOME" \
      "$XDG_CACHE_HOME" \
      "$XDG_RUNTIME_DIR"
    ln -s ${localPluginTree} "$XDG_CONFIG_HOME/noctalia/v5-plugins"
    ${noctalia}/bin/noctalia config validate ${./config.toml}
    cp ${./config.toml} "$out"
  '';
in
{
  # Use Home Manager's native v5 module for the package, TOML configuration,
  # config validation, and (when explicitly enabled later) systemd unit.
  # Keep systemd disabled for now: shell-services.nix intentionally continues
  # to start the existing Noctalia v4 shell until the v5 setup is accepted.
  programs.noctalia = {
    enable = true;
    package = noctalia;
    systemd.enable = false;
    # validatedConfig performs the same strict check with all local plugin
    # manifests available, so do not run the module's plugin-blind check again.
    checkConfig = false;
    settings = validatedConfig;
  };

  # The official recorder plugin uses this external backend. It is kept
  # separate from the shell package because Noctalia does not bundle it.
  home.packages = with pkgs; [
    gpu-screen-recorder
    # External-monitor DDC/CI controls used by the bottom display manager.
    ddcutil
    # V5 Screen Toolkit replacements for the V4 QML overlays.
    satty
    hyprpicker
    zbar
    wl-screenrec
    wf-recorder
    tesseract

    # Keep every existing Niri hotkey working with the default V4 shell while
    # transparently routing the same intent to V5 during side-by-side testing.
    # This does not alter shell-services.nix or which bar starts by default.
    (writeShellScriptBin "noctalia-compat" ''
      set -u

      if noctalia msg status >/dev/null 2>&1; then
        use_v5=1
      else
        use_v5=0
      fi

      action="''${1:-}"
      shift || true
      if [ "$use_v5" -eq 1 ]; then
        case "$action" in
          hotkeys)        exec noctalia msg panel-toggle baizhu/keybind_cheatsheet:panel ;;
          launcher)       exec noctalia msg panel-toggle launcher ;;
          emoji)          exec noctalia msg panel-toggle launcher /emo ;;
          clipboard)      exec noctalia msg panel-toggle clipboard ;;
          bar-toggle)     exec noctalia msg bar-toggle ;;
          desktop-toggle) exec noctalia msg desktop-widgets-toggle ;;
          notify)         exec noctalia msg notification-show "''${*:-Noctalia}" ;;
          toolkit)        exec noctalia msg plugin baizhu/screen_toolkit:service all "''${1:-toggle}" ;;
          media)          exec noctalia msg media "''${1:-toggle}" ;;
          brightness-up)  exec noctalia msg brightness-up current 5% ;;
          brightness-down) exec noctalia msg brightness-down current 5% ;;
          dark)           exec noctalia msg theme-mode-set dark ;;
          power-saver)    exec noctalia msg power-set power-saver ;;
          *) printf 'Unknown noctalia-compat action: %s\n' "$action" >&2; exit 2 ;;
        esac
      else
        case "$action" in
          hotkeys)        exec noctalia-shell ipc call plugin:keybind-cheatsheet toggle ;;
          launcher)       exec noctalia-shell ipc call launcher toggle ;;
          emoji)          exec noctalia-shell ipc call launcher emoji ;;
          clipboard)      exec noctalia-shell ipc call launcher clipboard ;;
          bar-toggle)     exec noctalia-shell ipc call bar toggle ;;
          desktop-toggle) exec noctalia-shell ipc call desktopWidgets toggle ;;
          notify)         exec noctalia-shell ipc call toast send "{\"title\":\"''${*:-Noctalia}\"}" ;;
          toolkit)        exec noctalia-shell ipc call plugin:screen-toolkit "''${1:-toggle}" ;;
          media)          exec noctalia-shell ipc call media "''${1:-toggle}" ;;
          brightness-up)  exec noctalia-shell ipc call brightness increase ;;
          brightness-down) exec noctalia-shell ipc call brightness decrease ;;
          dark)           exec noctalia-shell ipc call darkMode setDark ;;
          power-saver)    exec noctalia-shell ipc call powerProfile set powersaver ;;
          *) printf 'Unknown noctalia-compat action: %s\n' "$action" >&2; exit 2 ;;
        esac
      fi
    '')
  ];

  # Home Manager's Noctalia module manages config.toml but intentionally has
  # no plugin-source option, so keep the local v5 plugin tree declarative here.
  # The legacy ~/.config/noctalia/plugins/ tree remains untouched for v4.
  home.file = {
    # The existing wallpaper-theme-sync service consumes the legacy colors.json
    # shape. This v5 template regenerates that compatibility file whenever the
    # v5 wallpaper palette changes, keeping DMS, Waybar lyrics, and mouse-trail
    # synchronized without modifying the v4 shell service.
    ".config/noctalia/templates/noctalia-colors.json".source = ./noctalia-colors.json;
    ".config/noctalia/v5-plugins/catwalk-v5".source = localPluginSources."catwalk-v5";
    ".config/noctalia/v5-plugins/media-mini-v5".source = localPluginSources."media-mini-v5";
    ".config/noctalia/v5-plugins/network-monitor-v5".source = localPluginSources."network-monitor-v5";
    ".config/noctalia/v5-plugins/showmethekey-v5".source = localPluginSources."showmethekey-v5";
    ".config/noctalia/v5-plugins/todo-v5".source = localPluginSources."todo-v5";
    ".config/noctalia/v5-plugins/keybind-cheatsheet-v5".source = localPluginSources."keybind-cheatsheet-v5";
    ".config/noctalia/v5-plugins/screen-toolkit-v5".source = localPluginSources."screen-toolkit-v5";
    ".config/noctalia/v5-plugins/supergfxctl-v5".source = localPluginSources."supergfxctl-v5";
    ".config/noctalia/v5-plugins/v4-extras-v5".source = localPluginSources."v4-extras-v5";
    ".config/noctalia/v5-plugins/screen-recorder-v5".source = localPluginSources."screen-recorder-v5";
    ".config/noctalia/v5-plugins/bottom-bar-v5".source = localPluginSources."bottom-bar-v5";
  };
}
