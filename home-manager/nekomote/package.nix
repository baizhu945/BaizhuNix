{ lib, stdenv, fetchFromGitHub, cmake, ninja, pkg-config, python3Packages,
  wayland-scanner, glslang, nlohmann_json, fast-float, stb, flac, libpng,
  zlib, fontconfig, libpulseaudio, dbus, wayland, libglvnd, vulkan-headers,
  vulkan-loader, catch2_3 }:

let
  rev = "6a7d16b9d061061f4393c0e9f7996ebe60e3c7aa";
in stdenv.mkDerivation {
  pname = "nekomote-layer-shell";
  version = "0.6.2-gaze-${builtins.substring 0 7 rev}";
  src = fetchFromGitHub {
    owner = "<yourusername>";
    repo = "NekoMote";
    inherit rev;
    hash = "sha256-I1kAkthrSMTINdh63LBr382eoBVhqPlEliCA4PYH1/A=";
  };
  strictDeps = true;
  nativeBuildInputs = [ cmake ninja pkg-config python3Packages.glad2 glslang wayland-scanner ];
  buildInputs = [
    nlohmann_json fast-float stb flac libpng zlib fontconfig libpulseaudio
    dbus wayland libglvnd vulkan-headers vulkan-loader catch2_3
  ];
  cmakeFlags = [
    "-DNEKOMOTE_USE_SYSTEM_DEPS=ON" "-DNEKOMOTE_WERROR=OFF"
    "-DNEKOMOTE_BUILD_ABI=ON" "-DNEKOMOTE_BUILD_LAYER_SHELL=ON" "-DNEKOMOTE_BUILD_VULKAN=ON"
    "-DNEKOMOTE_BUILD_PREVIEW=OFF" "-DNEKOMOTE_BUILD_PLAYER=OFF" "-DNEKOMOTE_BUILD_TOOLS=OFF"
    "-DNEKOMOTE_BUILD_TESTS=ON"
  ];
  buildPhase = ''
    runHook preBuild
    cmake --build . --parallel 4 --target nekomote_layer_shell \
      nekomote_desktop_gaze_math_tests nekomote_layer_shell_option_tests
    runHook postBuild
  '';
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    ctest --output-on-failure -R '^layer_shell_(options|desktop_gaze_math)$'
    runHook postCheck
  '';
  installPhase = ''
    runHook preInstall
    cmake --install . --component layer_shell
    runHook postInstall
  '';
  meta = {
    homepage = "https://github.com/<yourusername>/NekoMote";
    description = "Native Wayland wallpaper with optional cross-output character gaze";
    platforms = lib.platforms.linux;
    mainProgram = "nekomote_layer_shell";
  };
}
