{ config, pkgs, ... }:

let
  pythonWithEdgeTts = pkgs.python313.withPackages (ps: [ ps.edge-tts ]);

  voices = {
    zh = "zh-CN-XiaoxiaoNeural";
    ja = "ja-JP-NanamiNeural";
    en = "en-US-JennyNeural";
  };

  tts-core = pkgs.writeShellScriptBin "tts-core" ''
    exec ${pythonWithEdgeTts}/bin/python3 ${./tts-core.py}
  '';

  speak = pkgs.writeShellScriptBin "speak" ''
    if [ -n "$1" ]; then
      echo "$1" | ${tts-core}/bin/tts-core
    else
      ${tts-core}/bin/tts-core
    fi
  '';

  speak-file = pkgs.writeShellScriptBin "speak-file" ''
    if [ ! -f "$1" ]; then
      echo "Usage: speak-file <file>" >&2
      exit 1
    fi
    ${tts-core}/bin/tts-core < "$1"
  '';

  speak-clip = pkgs.writeShellScriptBin "speak-clip" ''
    if ! command -v wl-paste &>/dev/null; then
      echo "wl-paste not found, install wl-clipboard" >&2
      exit 1
    fi
    TEXT=$(wl-paste --no-newline 2>/dev/null)
    if [ -z "$TEXT" ]; then
      echo "Clipboard is empty" >&2
      noctalia-shell ipc call toast send '{"title":"Clipboard is empty"}'
      exit 1
    fi
    echo "$TEXT" | ${tts-core}/bin/tts-core
  '';
in
{
  home.packages = [
    tts-core
    speak
    speak-file
    speak-clip
  ];

  home.file = {
    ".config/tts/voices.json".text = builtins.toJSON {
      zh = voices.zh;
      ja = voices.ja;
      en = voices.en;
    };
  };
}
