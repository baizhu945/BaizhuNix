{ config, pkgs, lib, ... }:

let
  cfg = config.services.pipewire.aptxAdaptive;
  
  runtimeDir = "/home/<yourusername>/Documents/aptx-adaptive-runtime";
  
  openaptx-adaptive = pkgs.stdenv.mkDerivation {
    pname = "openaptx-adaptive-protocol";
    version = "2.0.0";
    src = pkgs.fetchFromGitHub {
      owner = "<yourusername>";
      repo = "openaptx";
      rev = "ecab9fbb1f0e5441ee25f74c29f83dc3996503cd";
      hash = "sha256-1KG6pwC8BVRKttSO9irACtnkrODCmJFCrV5Tqaq4Ylg=";
    };

    nativeBuildInputs = [ pkgs.cmake pkgs.pkg-config ];
    cmakeFlags = [
      "-DENABLE_DOC=OFF"
      "-DWITH_FFMPEG=OFF"
      "-DWITH_FREEAPTX=OFF"
    ];
  };

  pipewire-aptx-adaptive = pkgs.pipewire.overrideAttrs (old: {
    pname = "pipewire-aptx-adaptive";
    version = "1.7.0-aptx-adaptive";
    src = pkgs.fetchFromGitHub {
      owner = "<yourusername>";
      repo = "pipewire";
      rev = "11eb043bd66b7bcdf33b804e72d43d57f1b622ee";
      hash = "sha256-/DkYb73UWJkCtW/jgzGJuO+c8oHPEep0aMkuZBfukD8=";
    };
    outputs = [ "out" "dev" "doc" "man" "jack" ];
    patches = [];
    buildInputs = (old.buildInputs or []) ++ [ openaptx-adaptive ];
    mesonFlags = (pkgs.lib.filter
      (flag: !(pkgs.lib.hasPrefix "-Dinstalled_test_prefix=" flag))
      (old.mesonFlags or [])) ++ [
      "-Dbluez5-codec-lhdc=disabled"
      "-Dbluez5-codec-aptx-adaptive=enabled"
    ];
    doCheck = false;
  });
  adaptiveEnv = {
    # The R3 encoder profile is the openaptx-info/Qualcomm aptX Lossless
    # profile (profile 6), exposed through the aptX Adaptive A2DP endpoint.
    PIPEWIRE_APTX_ADAPTIVE_HELPER =
      "${runtimeDir}/helper/aptx-lossless-helper";
    PIPEWIRE_APTX_ADAPTIVE_QEMU = "${pkgs.qemu}/bin/qemu-hexagon";
    PIPEWIRE_APTX_ADAPTIVE_SYSROOT = "${runtimeDir}/sysroot";
    APTX_ADAPTIVE_PROFILE = "6";
  };
in
{
  options.services.pipewire.aptxAdaptive.enable = lib.mkEnableOption
    "the experimental aptX Adaptive 2.2 / aptX Lossless bridge";

  config = lib.mkIf cfg.enable {
    # The helper and Qualcomm libraries are user-supplied files and are not
    # copied into the Nix store.
    services.pipewire.package = pipewire-aptx-adaptive;

    environment.variables = adaptiveEnv;
    systemd.user.services.pipewire.environment = adaptiveEnv;
    systemd.user.services.wireplumber.environment = adaptiveEnv;

    services.pipewire.wireplumber.extraConfig."aptx-adaptive" = {
      "monitor.bluez.properties" = {
        "bluez5.codecs" = [
          "sbc"
          "sbc_xq"
          "aac"
          "aac_eld"
          "aptx"
          "aptx_hd"
          "aptx_adaptive"
          "aptx_ll"
          "aptx_ll_duplex"
          "faststream"
          "faststream_duplex"
          "lc3plus_h3"
          "ldac"
          "opus_05"
          "opus_05_51"
          "opus_05_71"
          "opus_05_duplex"
          "opus_05_pro"
          "opus_g"
          "lc3"
        ];
      };
    };
  };
}
