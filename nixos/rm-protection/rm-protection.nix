{ config, pkgs, ... }:

let
  realRm = "${pkgs.coreutils}/bin/rm";
  
  rmPackage = pkgs.runCommand "rm-wrapper" {} ''
    mkdir -p $out/bin
    sed 's|@realRm@|${realRm}|g' ${./rm-protection.sh} > $out/bin/rm
    chmod +x $out/bin/rm
  '';

  rmDirect = pkgs.writeShellScriptBin "remove-without-permission" ''
    exec ${realRm} "$@"
  '';
in
{
  environment.systemPackages = [ rmPackage rmDirect ];

  environment.extraInit = ''
    export PATH="${rmPackage}/bin:$PATH"
  '';

  security.sudo.extraConfig = ''
    Defaults env_keep += "PATH"
  '';
}
