{ pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "<yourusername>";
    repo = "AniPlayer";
    rev = "95db14ddd69dbb73aa3a619de8c8cde9c1777bd2";
    hash = "sha256-R9Yz1POxNHvM+JXdOrx0RSisqtcPhC1jrYhDQvcB12Q=";
  };
in
{
  home.packages = [ (pkgs.callPackage "${src}/package.nix" { }) ];
}
