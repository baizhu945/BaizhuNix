{ config, pkgs, ... }:

{
  home.packages = [
    (pkgs.writeShellScriptBin "speak-zh" ''
      #!/usr/bin/env bash
      mkdir -p ~/Music/piper/
      MODEL="$HOME/.local/share/piper/zh_CN-huayan-medium.onnx"
      OUT="/home/baizhu945/Music/piper/$(date +%Y%m%d_%H%M%S_%3N).wav"
      echo "$1" | piper -m "$MODEL" -f "$OUT"
      aplay "$OUT"
    '')

    (pkgs.writeShellScriptBin "speak_from_clipboard-zh" ''
      #!/usr/bin/env bash
      mkdir -p ~/Music/piper/
      MODEL="$HOME/.local/share/piper/zh_CN-huayan-medium.onnx"
      OUT="/home/baizhu945/Music/piper/$(date +%Y%m%d_%H%M%S_%3N).wav"
      wl-paste --no-newline | piper -m "$MODEL" -f "$OUT"
      noctalia-shell ipc call toast send '{"title":"朗读已保存"}'
      aplay "$OUT"
    '')

    (pkgs.writeShellScriptBin "speak-en" ''
      #!/usr/bin/env bash
      mkdir -p ~/Music/piper/
      MODEL="$HOME/.local/share/piper/en_GB-cori-high.onnx"
      OUT="/home/baizhu945/Music/piper/$(date +%Y%m%d_%H%M%S_%3N).wav"
      echo "$1" | piper -m "$MODEL" -f "$OUT"
      aplay "$OUT"
    '')

    (pkgs.writeShellScriptBin "speak_from_clipboard-en" ''
      #!/usr/bin/env bash
      mkdir -p ~/Music/piper/
      MODEL="$HOME/.local/share/piper/en_GB-cori-high.onnx"
      OUT="/home/baizhu945/Music/piper/$(date +%Y%m%d_%H%M%S_%3N).wav"
      wl-paste --no-newline | piper -m "$MODEL" -f "$OUT"
      noctalia-shell ipc call toast send '{"title":"朗读已保存"}'
      aplay "$OUT"
    '')
  ];

  home.file = {
    ".local/share/piper/zh_CN-huayan-medium.onnx".source = 
      builtins.fetchurl "https://huggingface.co/rhasspy/piper-voices/resolve/main/zh/zh_CN/huayan/medium/zh_CN-huayan-medium.onnx";
    ".local/share/piper/zh_CN-huayan-medium.onnx.json".source =
      builtins.fetchurl "https://huggingface.co/rhasspy/piper-voices/resolve/main/zh/zh_CN/huayan/medium/zh_CN-huayan-medium.onnx.json";

    ".local/share/piper/en_GB-cori-high.onnx".source =
      builtins.fetchurl "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_GB/cori/high/en_GB-cori-high.onnx";
    ".local/share/piper/en_GB-cori-high.onnx.json".source =
      builtins.fetchurl "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_GB/cori/high/en_GB-cori-high.onnx.json";
  };
}
