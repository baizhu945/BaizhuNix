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
      rev = "da487f5c78c8d4c01f360d60cf1462a851bfeb6a";
      hash = "sha256-CtAemn5lq9CRg+Rsrym2/+uo6AS2m5AXAFTw1lfB+lA=";
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
      rev = "2245971dc5789842ca82d6be3fd1b7bab69f5e97";
      hash = "sha256-xWPpVoKdtCvCrNxeRwxQWNgdyyPPQjNw8tXsqsaKpQk=";
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
    # The R2 CAPI wrapper is the local Qualcomm entry point for normal
    # Adaptive R2/R2.2 streams. The PipeWire plugin derives the extension
    # stream from the peer's negotiated CIE instead of forcing one value.
    PIPEWIRE_APTX_ADAPTIVE_HELPER = "${runtimeDir}/helper/aptx-lossless-helper";
    PIPEWIRE_APTX_ADAPTIVE_QEMU = "${pkgs.qemu}/bin/qemu-hexagon";
    PIPEWIRE_APTX_ADAPTIVE_SYSROOT = "${runtimeDir}/sysroot";
    PIPEWIRE_APTX_ADAPTIVE_MODE = "r2";
    APTX_ADAPTIVE_PROFILE = "6";
    APTX_ADAPTIVE_LOSSLESS = "off";
    APTX_ADAPTIVE_QHS_SUPPORT = "0";
    APTX_ADAPTIVE_ABR = "1";
  };
in
{
  options.services.pipewire.aptxAdaptive.enable = lib.mkEnableOption
    "the experimental aptX Adaptive R2/R2.2 bridge";

  config = lib.mkIf cfg.enable {
    # The helper and Qualcomm libraries are user-supplied files and are not
    # copied into the Nix store.
    services.pipewire.package = pipewire-aptx-adaptive;

    environment.variables = adaptiveEnv;
    systemd.user.services.pipewire.environment = adaptiveEnv;
    systemd.user.services.wireplumber.environment = adaptiveEnv;
    # Never inherit a fixed diagnostic CIE from the user manager.  The
    # Adaptive plugin must use the peer's negotiated stream on the AX210
    # path; fixed overrides are only for explicit, out-of-band experiments.
    systemd.user.services.pipewire.serviceConfig.UnsetEnvironment = [
      "APTX_ADAPTIVE_CONFIG_STREAM_HEX"
    ];
    systemd.user.services.wireplumber.serviceConfig.UnsetEnvironment = [
      "APTX_ADAPTIVE_CONFIG_STREAM_HEX"
    ];

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
