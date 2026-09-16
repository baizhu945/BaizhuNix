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

  # Pin the upstream v5 screen-recorder plugin instead of using the legacy
  # manifest.json plugin. The plugin source is immutable under ~/.local/share,
  # while its runtime state remains in Noctalia's state directory.
  officialPlugins = pkgs.fetchFromGitHub {
    owner = "noctalia-dev";
    repo = "official-plugins";
    rev = "62b1830eb1e76998c7e3b8133de608f79c6c1be8";
    hash = "sha256-ElPRXtrMhuADPgMdITPWnBPmylG+CEZB69Lk2YSua+I=";
  };

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

    # The host PipeWire is a custom 1.7.x build, while Home Manager's
    # pkgs.pipewire client library is 1.6.x. Upstream's version probe checks
    # the client library, so it would incorrectly select passive=true at
    # runtime. PipeWire 1.7 is the deployed system invariant; select the
    # compatible in-follow mode unconditionally for this package.
    postPatch = ''
      substituteInPlace src/pipewire/pipewire_spectrum.cpp \
        --replace-fail 'const char* const passiveMode = pw_check_library_version(1, 7, 0) ? "in-follow" : "true";' \
          'const char* const passiveMode = "in-follow";'
    '';

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
  home.packages = [
    noctalia-v5
    pkgs.gpu-screen-recorder
  ];

  # Noctalia v5 scans the configured path source for plugin.toml entries. Keep
  # these ports declarative and leave the legacy v4 QML tree untouched.
  home.file = {
    ".config/noctalia/v5-plugins/catwalk-v5".source = ./noctalia-v5-plugins/catwalk-v5;
    ".config/noctalia/v5-plugins/media-visualizer-v5".source = ./noctalia-v5-plugins/media-visualizer-v5;
    ".config/noctalia/v5-plugins/showmethekey-v5".source = ./noctalia-v5-plugins/showmethekey-v5;
    ".config/noctalia/v5-plugins/todo-v5".source = ./noctalia-v5-plugins/todo-v5;
    ".config/noctalia/v5-plugins/keybind-cheatsheet-v5".source = ./noctalia-v5-plugins/keybind-cheatsheet-v5;
    ".config/noctalia/v5-plugins/screen-toolkit-v5".source = ./noctalia-v5-plugins/screen-toolkit-v5;
    ".config/noctalia/v5-plugins/supergfxctl-v5".source = ./noctalia-v5-plugins/supergfxctl-v5;
    ".config/noctalia/v5-plugins/v4-extras-v5".source = ./noctalia-v5-plugins/v4-extras-v5;
    ".config/noctalia/v5-plugins/screen-recorder-v5".source = "${officialPlugins}/screen_recorder";
  };
}
