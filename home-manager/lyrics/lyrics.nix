{ config, lib, pkgs, ... }:

let
  lyricsScript = builtins.readFile ./lyrics.py;
  lyrics-script = pkgs.writers.writePython3Bin "waybar-lyrics" {
    libraries = with pkgs.python3Packages; [ requests ];
  } lyricsScript;

  toggle-script = pkgs.writeShellScriptBin "lyrics-toggle" ''
    STATE_FILE="/tmp/waybar_lyrics_show"
    touch "$STATE_FILE"
    [ "$(cat $STATE_FILE)" = "true" ] \
      && echo "false" > "$STATE_FILE" \
      || echo "true" > "$STATE_FILE"
    pkill -RTMIN+8 waybar || true
  '';

in
{
  home.packages = [ 
    pkgs.playerctl 
    lyrics-script 
    toggle-script 
  ];
}
