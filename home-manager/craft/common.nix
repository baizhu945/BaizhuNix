{ pkgs, lib }:

let
  craftFonts = pkgs.fetchFromGitHub {
    owner = "storytold";
    repo = "craft-fonts";
    rev = "abb83316d96aa59c1cf64784289e378fe9fa5695";
    hash = "sha256-e+6HpOYoAFTh6mNfGBBw2njnBzcE8W8+Jybv1+dKOCA=";
  };

  notoCjk =
    "${pkgs.noto-fonts-cjk-sans}/share/fonts/opentype/noto-cjk/NotoSansCJK-VF.otf.ttc";
  wqyZenhei = "${pkgs.wqy_zenhei}/share/fonts/truetype/wqy-zenhei.ttc";

  openglDriverLib = "/run/opengl-driver/lib";
  openglDriverShare = "/run/opengl-driver/share";

  waylandRuntime = with pkgs; [
    vulkan-loader
    wayland
    libxkbcommon
    libglvnd
    libgbm
    egl-wayland
  ];

  craftLinuxDeps = with pkgs; [
    libxkbcommon
    wayland
    libx11
    libxrandr
    libxi
    libglvnd
    libgbm
    egl-wayland
    gtk3
    vulkan-loader
    noto-fonts-cjk-sans
    wqy_zenhei
    alsa-lib
  ];

  craftNativeBuildInputs = with pkgs; [
    pkg-config
    installShellFiles
    wrapGAppsHook3
    makeWrapper
    addDriverRunpath
  ];

  patchCjkFontPaths = ''
    if [ -f crates/text/src/cjk.rs ]; then
      sed -i \
        -e 's|"/usr/share/fonts/[^"]*NotoSansCJK[^"]*"|"${notoCjk}"|g' \
        -e 's|"/usr/local/share/fonts/[^"]*NotoSansCJK[^"]*"|"${notoCjk}"|g' \
        -e 's|"/usr/share/fonts/[^"]*wqy[^"]*"|"${wqyZenhei}"|g' \
        -e 's|"/usr/share/fonts/wenquanyi/[^"]*"|"${wqyZenhei}"|g' \
        crates/text/src/cjk.rs
    fi
  '';

  wrapCraftGuiBins =
    {
      bins,
      wrappedBins ? bins,
      extraEnv ? [ ],
    }:
    lib.optionalString pkgs.stdenv.hostPlatform.isLinux (
      let
        envFlags = lib.concatMap (
          { name, value }:
          [
            "--set-default"
            name
            value
          ]
        ) extraEnv;
      in
      ''
        ${lib.concatStringsSep "\n" (map (b: "addDriverRunpath $out/bin/.${b}-wrapped") wrappedBins)}
        for bin in ${lib.concatStringsSep " " bins}; do
          wrapProgram $out/bin/$bin \
            --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath waylandRuntime}" \
            --prefix LD_LIBRARY_PATH : "${openglDriverLib}" \
            --set-default WGPU_BACKEND vulkan \
            --set-default VK_ICD_FILENAMES ${openglDriverShare}/vulkan/icd.d/nvidia_icd.json \
            --set-default __EGL_VENDOR_LIBRARY_FILENAMES ${openglDriverShare}/glvnd/egl_vendor.d/10_nvidia.json \
            ${lib.concatStringsSep " " envFlags}
        done
      ''
    );
in
{
  inherit
    craftFonts
    craftLinuxDeps
    craftNativeBuildInputs
    patchCjkFontPaths
    wrapCraftGuiBins
    ;
}
