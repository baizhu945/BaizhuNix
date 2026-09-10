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
      # 2026-09-10: 代码审查修复（write_full 无超时、STRIP_OTA=0 失效、
      # FEATURES 覆盖重新引入 R2.2 位、ABR 等级反向、R3 静态属性入口错误、
      # helper 子进程信号掩码/fd 泄漏、get_delay 单位）。
      # 详见 research/aptx-adaptive-qemu/CODE-REVIEW.md。
      rev = "b97eae8c84b3b253429461abbb7c6c099cbe36cc";
      hash = "sha256-jVrl8n1DmTEBJxtkAB6TVMjyko7kScF7wTgoCN0ykiI=";
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
  # WirePlumber must be built against the same PipeWire as the codec plugin:
  # its compiled-in SPA/module search paths and the SPA ABI otherwise come
  # from the stock PipeWire and the aptX Adaptive codec is never discovered
  # (or, if forced via env vars, the mixed modules fail to create nodes).
  wireplumber-aptx-adaptive = pkgs.wireplumber.override {
    pipewire = pipewire-aptx-adaptive;
  };
  adaptiveEnv = {
    # The helper is a plain executable outside the Nix store; it is rebuilt
    # locally and referenced by path so that the runtime always matches the
    # source in ~/work/openaptx (see research/aptx-adaptive-qemu/CODE-REVIEW.md).
    PIPEWIRE_APTX_ADAPTIVE_HELPER = "${runtimeDir}/helper/aptx-lossless-helper";
    PIPEWIRE_APTX_ADAPTIVE_QEMU = "${pkgs.qemu}/bin/qemu-hexagon";
    PIPEWIRE_APTX_ADAPTIVE_SYSROOT = "${runtimeDir}/sysroot";
    PIPEWIRE_APTX_ADAPTIVE_MODE = "r2";
    # 仅 R3 模式使用；R2 路径的 profile 由协商出的 CIE 决定，此变量被忽略。
    APTX_ADAPTIVE_PROFILE = "6";
    # 只改本地 CIE 的低 3 位，不改协商出的采样率/声道。
    APTX_ADAPTIVE_SOURCE_TYPE = "0x00";
    APTX_ADAPTIVE_CHANNEL_MODE = "stereo";
    # Lossless 能力位必须与 R3 编码器一致：off 会在协商时清掉 R2.2 的
    # 0x80 位，对端就不会进入 Lossless。force 保留该位并由 R3 直编管线
    # 产出 0xad 码流。
    APTX_ADAPTIVE_LOSSLESS = "off";
    # AX210 没有 Qualcomm High Speed Link，不能宣称支持 QHS。
    APTX_ADAPTIVE_QHS_SUPPORT = "0";
    # 保留控制面，但实测该编码器构建不响应 quality-level 反馈，
    # 码率固定（48 kHz 约 212 kbps），详见插件初始化日志。
    APTX_ADAPTIVE_ABR = "1";
    # 这里只放"默认就该这样"的开关。诊断用的一次性开关（STRIP_OTA、CAPTURE、
    # FORCE_RATE、CODEC_FRAMES、FREQ_BITS、FEATURES、R2_PROFILE、
    # APTX_TTP_MODE、APTX_OTA_VERSION…）一律不要写进模块：它们在 2026-09-10
    # 的代码审查里被发现会静默改变线上格式（STRIP_OTA=1 会把 OTA 头剥掉、
    # CAPTURE 会把码流写进 /tmp、FORCE_RATE 会把所有内容重采样到 44.1 kHz）。
    # 需要时放进 ~/.config/systemd/user/*/zzz-*.conf 里临时启用。
  };
in
{
  options.services.pipewire.aptxAdaptive.enable = lib.mkEnableOption
    "the experimental aptX Adaptive R2/R2.2 bridge";

  config = lib.mkIf cfg.enable {
    # The helper and Qualcomm libraries are user-supplied files and are not
    # copied into the Nix store.
    services.pipewire.package = pipewire-aptx-adaptive;

    # Only the two services that host the codec need the helper environment.
    # Exporting it through environment.variables leaked the encoder
    # configuration, including diagnostic switches, into every process of the
    # system.
    systemd.user.services.pipewire.environment = adaptiveEnv;
    systemd.user.services.wireplumber.environment = adaptiveEnv;
    # Use the WirePlumber build that matches the aptX Adaptive PipeWire.
    services.pipewire.wireplumber.package = wireplumber-aptx-adaptive;
    # Never inherit a fixed diagnostic CIE from the user manager.  The
    # Adaptive plugin must use the peer's negotiated stream on the AX210
    # path; fixed overrides are only for explicit, out-of-band experiments.
    # The helper is a qemu-hexagon process spawned by WirePlumber.  QEMU's
    # TCG JIT needs writable+executable pages, which the default hardening
    # (MemoryDenyWriteExecute=yes) blocks: the codec then fails to start with
    # "qemu_mprotect__osdep: mprotect failed: Permission denied" and the sink
    # stays silent.  Relax it only for the two services that host the codec.
    #
    # RISK: while this module is enabled those two user services run without
    # W^X, whether or not an aptX Adaptive stream is active (the hardening flag
    # is static per unit).  Setting services.pipewire.aptxAdaptive.enable=false
    # is therefore the way to get the protection back; use that instead of
    # leaving the module imported "just in case".
    systemd.user.services.pipewire.serviceConfig = {
      MemoryDenyWriteExecute = false;
      UnsetEnvironment = [ "APTX_ADAPTIVE_CONFIG_STREAM_HEX" ];
    };
    systemd.user.services.wireplumber.serviceConfig = {
      MemoryDenyWriteExecute = false;
      UnsetEnvironment = [ "APTX_ADAPTIVE_CONFIG_STREAM_HEX" ];
    };

    services.pipewire.wireplumber.extraConfig."aptx-adaptive" = {
      "monitor.bluez.properties" = {
        "bluez5.codecs" = [
          "sbc"
          "sbc_xq"
          "aac"
          "aac_eld"
          # 注意：这个数组只是"允许哪些编码器"的集合，顺序不影响优先级 —— 真正
          # 的优先级来自编译期的 codec_order()，其中 aptX Adaptive 排在 aptX HD
          # **之前**。耳机最终选谁由协商决定（实测默认落到 HD，能出声）；保留
          # aptx_adaptive 是为了能用 wpctl set-profile 手动切过去做实验。
          # 想彻底避免误选到（目前静音的）AD，把 "aptx_adaptive" 这一行删掉即可。
          "aptx_hd"
          "aptx_adaptive"
          "aptx"
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
      # Do not fall back to the headset (HFP/CVSD) profile when anything opens
      # a capture stream: that silently downgrades aptX Adaptive to CVSD and
      # the A2DP stream stops (observed as ~2 kB/s and no audio).
      "wireplumber.settings" = {
        "bluetooth.autoswitch-to-headset-profile" = false;
      };
    };
  };
}
