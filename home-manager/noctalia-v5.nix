{ config, pkgs, lib, ... }:

let
  stb' = pkgs.stb.overrideAttrs (_: {
    version = "unstable-2025-10-26";
    src = pkgs.fetchFromGitHub {
      owner = "nothings";
      repo = "stb";
      rev = "f1c79c02822848a9bed4315b12c8c8f3761e1296";
      hash = "sha256-BlyXJtAI7WqXCTT3ylww8zoG0hBxaojJnQDvdQOXJPE=";
    };
  });

  noctalia-v5 = pkgs.stdenv.mkDerivation {
    pname = "noctalia-v5";
    version = "5c7e2fb";

    src = pkgs.fetchFromGitHub {
      owner = "noctalia-dev";
      repo = "noctalia";
      rev = "5c7e2fba2338125339c6556b5cfb0ca5864ea448";
      sha256 = "sha256-mUIn6L5GRdbii+rM9sj68fj19TbQAbFsV8hvbOYBvp8=";
    };

    nativeBuildInputs = with pkgs; [ meson ninja pkg-config wayland-scanner jemalloc ];
    buildInputs = with pkgs; [
      wayland wayland-protocols libGL libglvnd freetype fontconfig
      cairo pango harfbuzz libxkbcommon sdbus-cpp_2 systemd pipewire
      wireplumber pam curl libwebp glib polkit librsvg libqalculate
      libxml2 md4c stb' nlohmann_json tomlplusplus
    ];

    postPatch = ''
      sed -i "s/'-march=native', '-mtune=native',//" meson.build
    '';

    mesonBuildType = "release";
    ninjaFlags = [ "-v" ];

    meta = with lib; {
      description = "A sleek Wayland desktop shell for Niri and other compositors";
      homepage = "https://github.com/noctalia-dev/noctalia";
      license = lib.licenses.mit;
      platforms = lib.platforms.linux;
      mainProgram = "noctalia";
    };
  };
in
{
  home.packages = [ noctalia-v5 ];
}
