{ config, lib, pkgs, ... }:

let
  lyricsScript = builtins.readFile ./lyrics.py;
  lyrics-script = pkgs.writers.writePython3Bin "waybar-lyrics" {
    libraries = with pkgs.python3Packages; [ requests ];
  } lyricsScript;

  toggle-script = pkgs.writeShellScriptBin "lyrics-toggle" ''
    set -euo pipefail

    # Keep this path compatible with existing Waybar processes.
    state_file="/tmp/waybar_lyrics_show"
    state_dir="$(dirname "$state_file")"
    ${pkgs.coreutils}/bin/mkdir -p "$state_dir"

    current="$(${pkgs.coreutils}/bin/cat "$state_file" 2>/dev/null || printf 'true')"
    if [ "$current" = "true" ]; then
      next="false"
    else
      next="true"
    fi

    # Replace atomically so the long-running Python modules never read a
    # half-written state value.  The PID makes simultaneous toggles separate.
    temporary="$state_file.$$"
    printf '%s\n' "$next" > "$temporary"
    ${pkgs.coreutils}/bin/mv -f "$temporary" "$state_file"
    # waybar-lyrics polls this tiny state file every 250 ms; no signal is
    # needed, and this also works with an already-running Waybar instance.
  '';

in
{
  home.packages = [
    pkgs.playerctl
    lyrics-script
    toggle-script
  ];
}
