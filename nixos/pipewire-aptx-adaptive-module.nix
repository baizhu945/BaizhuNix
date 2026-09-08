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
      # 2026-09-08: 修复 helper（44.1 kHz 卡死、R3 崩溃、Lossless 谎报）
      # 后续: 补齐 64 位 builtins、遵循 CAPI 初始化契约、修正 R3 环形游标语义
      rev = "c5fdab9ff7118fce16486b368fe57709adc90b3f";
      hash = "sha256-Xrv9r+Xb/I1NKYOd1TVpspP0rN6pZiG4jHW4wsDxe2o=";
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
      # 2026-09-08: R3 直编管线支持全速率；移除过时的 QHS 警告。
      # helper 读取增加 poll 超时；记录 ABR 的已知限制。
      rev = "90cb7d74e4978b8598e8d9f40ee77523a8ecd5ec";
      hash = "sha256-5ZzI/BU2oCh3ofec7ggNovwtSIoMcQFR9f1aWGKV5t8=";
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
    # The helper drives the R3 encoder through a direct encoding pipeline
    # (aptX3Encode(ctx, input_descriptor, output_descriptor)) which produces
    # real Lossless bitstreams; the R2 CAPI wrapper remains available for
    # plain Adaptive by setting this back to "r2".
    PIPEWIRE_APTX_ADAPTIVE_HELPER = "${runtimeDir}/helper/aptx-lossless-helper";
    PIPEWIRE_APTX_ADAPTIVE_QEMU = "${pkgs.qemu}/bin/qemu-hexagon";
    PIPEWIRE_APTX_ADAPTIVE_SYSROOT = "${runtimeDir}/sysroot";
    PIPEWIRE_APTX_ADAPTIVE_MODE = "r3";
    # 仅 R3 模式使用；R2 路径的 profile 由协商出的 CIE 决定，此变量被忽略。
    APTX_ADAPTIVE_PROFILE = "6";
    # Lossless 能力位必须与 R3 编码器一致：off 会在协商时清掉 R2.2 的
    # 0x80 位，对端就不会进入 Lossless。force 保留该位并由 R3 直编管线
    # 产出 0xad 码流。
    APTX_ADAPTIVE_LOSSLESS = "force";
    # AX210 没有 Qualcomm High Speed Link，不能宣称支持 QHS。
    APTX_ADAPTIVE_QHS_SUPPORT = "0";
    # 保留控制面，但实测该编码器构建不响应 quality-level 反馈，
    # 码率固定（48 kHz 约 212 kbps），详见插件初始化日志。
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
