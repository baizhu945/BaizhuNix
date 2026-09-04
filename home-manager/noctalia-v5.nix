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
    version = "5.0.1";

    src = pkgs.fetchFromGitHub {
      owner = "noctalia-dev";
      repo = "noctalia";
      rev = "f95e95cafde8c23f1d3a62b969e2b5717c96d741";
      hash = "sha256-diS3b69rt/IqehH/8Tsd8/JEQmogVc1ml6FP+iTwBzg=";
    };

    nativeBuildInputs = with pkgs; [
      meson ninja pkg-config wayland-scanner jemalloc makeWrapper
      autoAddDriverRunpath
    ];
    buildInputs = with pkgs; [
      wayland wayland-protocols libGL libglvnd freetype fontconfig
      cairo pango harfbuzz libxkbcommon sdbus-cpp_2 systemd pipewire
      wireplumber pam curl libwebp libjxl libsndfile glib polkit librsvg
      libqalculate libxml2 md4c libsecret libsodium stb' nlohmann_json
      tomlplusplus libical
    ];

    postFixup = ''
      wrapProgram $out/bin/noctalia \
        --prefix PATH : ${lib.makeBinPath [ pkgs.git ]} \
        --prefix XDG_DATA_DIRS : "${pkgs.glib.getSchemaDataDirPath pkgs.gsettings-desktop-schemas}"

      $out/bin/noctalia completions bash | install -D /dev/stdin $out/share/bash-completion/completions/noctalia
      $out/bin/noctalia completions zsh  | install -D /dev/stdin $out/share/zsh/site-functions/_noctalia
      $out/bin/noctalia completions fish | install -D /dev/stdin $out/share/fish/vendor_completions.d/noctalia.fish
    '';

    mesonBuildType = "release";
    mesonFlags = [ "-Dtests=disabled" ];
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
