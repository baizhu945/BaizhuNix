{ pkgs, lib, config, ... }:

let
  toggle-showmethekey = pkgs.writeShellScriptBin "showmethekey-toggle" ''
    #!/usr/bin/env bash
    
    FLAG="/tmp/showkeys-enabled"
    
    if [[ -e "$FLAG" ]]; then
        remove-without-permission -f "$FLAG"
    else
        touch "$FLAG"
    fi
  '';
in
{
  home.packages = [ toggle-showmethekey ];
  home.file = {
    ".local/bin/showmethekey-cli.py".source = ./showmethekey-cli.py;
  };
}
