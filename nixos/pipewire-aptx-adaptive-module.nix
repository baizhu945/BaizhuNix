{ config, pkgs, lib, ... }:

let
  cfg = config.services.pipewire.aptxAdaptive;

  # ---------------------------------------------------------------------------
  # Sources.  Everything the running setup needs comes from the two public
  # repositories; nothing is read from a local working directory any more.
  #
  #   * [open]aptx carries the SPA codec ABI 17 patch and the transport parser
  #     (pull request #17).  The patch is applied to the encoder below.
  #   * theacrat/aptx-linux is the clean-room aptX Adaptive encoder (MIT).
  #
  # The one input that cannot be fetched is Qualcomm's own encoder library: the
  # encoder reads its codec tables out of it at build time.  It is declared as
  # `vendorEncoder` below and is never redistributed.
  # ---------------------------------------------------------------------------
  # The encoder comes from this account's fork of theacrat/aptx-linux, which
  # carries two commits on top of the last upstream commit (a30bbd8):
  #
  #   a946958  compat: SPA codec ABI 17 (PipeWire 1.7)
  #   1412f0b  accept the alternate 44.1 kHz rate bit and offer 44.1 kHz to
  #            2.2 sinks
  #   889aab3  read the wanted sample rate from a run-time file, so a rate
  #            change only rebuilds the transport instead of restarting
  #            WirePlumber (which drops the Bluetooth link)
  #
  # Upstream is unmaintained and read-only, so the fixes are carried in the
  # fork instead of being sent as a pull request.
  aptxLinuxSrc = pkgs.fetchFromGitHub {
    owner = "<yourusername>";
    repo = "aptx-linux";
    rev = "889aab391460e836630434092b81e318df5d40a1";
    hash = "sha256-5GYufkQvz8vJ7oA3blW1Z51fuqj+cDrDBijvYOh8gcs=";
  };

  # The workspace declares rust-version = 1.99 and edition 2024; nixpkgs'
  # rustc (1.98) is too old, so the encoder is built with the same nightly
  # toolchain source the system already uses for the command line.
  #
  # Pinned to one commit with a fixed hash: the upstream "monthly" branch moves,
  # and an unpinned fetch would change the toolchain - and with it the encoder
  # and everything built from it - without any change here.  To update it, bump
  # the revision and the hash together:
  #
  #   git ls-remote https://github.com/nix-community/fenix monthly
  #   nix-prefetch-url --unpack \
  #     https://github.com/nix-community/fenix/archive/<rev>.tar.gz
  fenix = import (pkgs.fetchFromGitHub {
    owner = "nix-community";
    repo = "fenix";
    rev = "025bf5b6b0293c5ee3a3506a7e43ba64bc8bb1b7";
    hash = "sha256-am3DS8g9vyeQLKk9QQvmJoZLHGBUB1rtd6zVaGeq2Mc=";
  }) { };
  rustPlatform = pkgs.makeRustPlatform {
    cargo = fenix.complete.toolchain;
    rustc = fenix.complete.toolchain;
  };

  # The encoder plugin, built from source.  It lands in PipeWire's bluez5 codec
  # directory under the name of the codec slot it takes over (aptx).
  aptxAdaptivePlugin = rustPlatform.buildRustPackage {
    pname = "spa-codec-aptx-adaptive";
    version = "0.1.0-unstable-2026-10-16";
    src = aptxLinuxSrc;
    cargoLock.lockFile = "${aptxLinuxSrc}/Cargo.lock";
    # build.rs reads the codec tables from the vendor encoder at build time.
    APTX_ADAPTIVE_SO = "${cfg.vendorEncoder}";
    doCheck = false;
    postInstall = ''
      # The cargo hook builds with an explicit --target, so the cdylib is not in
      # target/release but under target/<triple>/release.
      lib=$(find target -name 'libspa_codec_aptx_adaptive.so' -print -quit)
      test -n "$lib"
      install -Dm755 "$lib" \
        $out/lib/spa-0.2/bluez5/libspa-codec-bluez5-aptx.so
    '';
    meta = {
      description = "Clean-room aptX Adaptive encoder as a PipeWire bluez5 codec";
      homepage = "https://github.com/theacrat/aptx-linux";
      license = lib.licenses.mit;
      platforms = lib.platforms.linux;
    };
  };

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

  pipewire-aptx-fork = pkgs.pipewire.overrideAttrs (old: {
    pname = "pipewire-aptx-adaptive";
    version = "1.7.0-aptx-adaptive";
    src = pkgs.fetchFromGitHub {
      owner = "<yourusername>";
      repo = "pipewire";
      # 2026-10-13: adds APTX_ADAPTIVE_TS_CONSTANT (constant RTP timestamp
      # for SOURCE_TYPE_2 sinks; off by default, enabled per-experiment
      # through the user-service drop-in).
      # 2026-09-11: adds APTX_ADAPTIVE_ADVERTISE_R2_2 (report the R2.2
      # capability to the peer while the encoder keeps its ordinary R2 path).
      # The option is off by default, so the deployed stream is unchanged;
      # it exists because the byte-identical Qualcomm configuration had to be
      # testable.  See research/aptx-adaptive-qemu/HANDOFF.md section 21.
      rev = "eefe57e41acc0f2130533e3138dc29dcb62a862b";
      hash = "sha256-1/6wXuiayzCPaOxYCJJRgYtT2M1xghivN8niuus0pEA=";
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

  # The clean-room encoder handles Adaptive sinks itself and passes everything
  # else (plain aptX, aptX HD) through to PipeWire's own codec.  It locates that
  # codec by looking for `bluez5/libspa-codec-bluez5-aptx.so` in SPA_PLUGIN_DIR,
  # or in a directory baked in at build time - and that probe needs pkg-config
  # and libspa-0.2, neither of which exists in the Nix build sandbox, so it falls
  # back to /usr/lib/spa-0.2 and reports "aptX/aptX HD unavailable".  Without the
  # passthrough a headset that does not negotiate Adaptive has no aptX fallback
  # and the link can drop to CVSD.  Keep a copy of the genuine codec from this
  # same 1.7 build (nixpkgs' stock PipeWire is 1.6.9, whose codec ABI is 16 and
  # would not match) and list it after the Adaptive directory below.
  realAptxCodecDir = pkgs.runCommand "aptx-real-codec" { } ''
    install -Dm755 \
      ${pipewire-aptx-fork}/lib/spa-0.2/bluez5/libspa-codec-bluez5-aptx.so \
      $out/bluez5/libspa-codec-bluez5-aptx.so
  '';

  pipewire-aptx-adaptive = pipewire-aptx-fork.overrideAttrs (old: {
    # Ship the clean-room encoder in the bluez5 codec slot it claims (aptx,
    # see theacrat/aptx-linux docs/adr/0004-aptx-slot.md).  Installing it into
    # the package itself - rather than pointing SPA_PLUGIN_DIR at a user
    # directory - keeps the codec bound to the PipeWire build it was compiled
    # against: a store path inside SPA_PLUGIN_DIR goes stale (and can be
    # garbage collected) on the next system rebuild, and a stale entry there
    # replaces PipeWire's entire plugin search path, not just the codec.
    # SPA_PLUGIN_DIR still lists this directory first and the passthrough copy
    # second, so PipeWire loads the Adaptive codec here while the plugin itself
    # finds the genuine one there.
    postInstall = (old.postInstall or "") + ''
      install -Dm755 ${aptxAdaptivePlugin}/lib/spa-0.2/bluez5/libspa-codec-bluez5-aptx.so \
        $out/lib/spa-0.2/bluez5/libspa-codec-bluez5-aptx.so
    '';
  });
  # WirePlumber must be built against the same PipeWire as the codec plugin:
  # its compiled-in SPA/module search paths and the SPA ABI otherwise come
  # from the stock PipeWire and the aptX Adaptive codec is never discovered
  # (or, if forced via env vars, the mixed modules fail to create nodes).
  wireplumber-aptx-adaptive = pkgs.wireplumber.override {
    pipewire = pipewire-aptx-adaptive;
  };
  adaptiveEnv = {
    # The legacy bridge is the only part that still needs user-supplied files
    # outside the store: a Hexagon helper binary and its sysroot, both built
    # and kept by hand.  See capiBridge.runtimeDir below.
    PIPEWIRE_APTX_ADAPTIVE_HELPER = "${cfg.capiBridge.runtimeDir}/helper/aptx-lossless-helper";
    PIPEWIRE_APTX_ADAPTIVE_QEMU = "${pkgs.qemu}/bin/qemu-hexagon";
    PIPEWIRE_APTX_ADAPTIVE_SYSROOT = "${cfg.capiBridge.runtimeDir}/sysroot";
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
  options.services.pipewire.aptxAdaptive = {
    enable = lib.mkEnableOption
      "the aptX Adaptive A2DP source (clean-room encoder in the aptx slot)";

    vendorEncoder = lib.mkOption {
      type = lib.types.path;
      example = "/run/keys/libaptXAdaptiveEnc.so";
      description = ''
        Qualcomm's aptX Adaptive encoder library.  The clean-room encoder reads
        its codec tables from this file at build time; nothing else uses it, and
        it is never redistributed.

        The file must be added to the store first, so that the hash below is
        verified before it is used:

        ```sh
        nix-store --add-fixed sha256 /path/to/libaptXAdaptiveEnc.so
        ```

        The copy from the OnePlus 15 (CPH2749) package is what this hash pins;
        it lives at work/aptxlibs_CPH2749/libaptXAdaptiveEnc.so and has to be
        added to the store again after a garbage collection:

          nix-store --add-fixed sha256 \
            /home/<yourusername>/work/aptxlibs_CPH2749/libaptXAdaptiveEnc.so
      '';
      default = pkgs.requireFile {
        name = "libaptXAdaptiveEnc.so";
        sha256 = "1ac881571cd1db4d256113d4448304016de73fedebc059824b1b2ed09599f0c9";
        message = ''
          libaptXAdaptiveEnc.so is not in the Nix store yet.  Add the vendor
          library once, then rebuild:

            nix-store --add-fixed sha256 /path/to/libaptXAdaptiveEnc.so

          The file is only read while building the encoder and is never
          redistributed by this configuration.
        '';
      };
      defaultText = lib.literalExpression "pkgs.requireFile { … }";
    };

    defaultRate = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ 44100 48000 96000 ]);
      default = null;
      example = 96000;
      description = ''
        Sample rate the Adaptive link negotiates.  The encoder accepts 44100,
        48000 and 96000 Hz; 96000 uses a different bitrate table (level 5 is
        646 kbps at 8 ms) and cannot run the low-latency profile, which is why
        48000 is the default.

        Left unset, PipeWire's bluez5 default of 48000 Hz applies.  The value is
        read when the bluez5 monitor starts and the codec configuration is
        picked when the transport is set up, so restart WirePlumber and
        reconnect the headset after changing it.

        Note that the encoder also accepts a run-time file
        ($XDG_RUNTIME_DIR/aptx-adaptive-rate, or APTX_ADAPTIVE_RATE_FILE), which
        wins over this value.  Together with the A2DP profile bounce `ad-ctl`
        performs, that changes the link rate in 5-6 s with no WirePlumber
        restart and no Bluetooth reconnect (measured: zero HCI disconnect
        events, headset stays connected).

        This option is the *pinned* default.  For the adaptive policy the user
        configuration uses instead - HQ follows the playing source's rate, low
        latency pins 48 kHz - see `ad-ctl rate auto` / `ad-ctl switch` and the
        `aptx-adaptive-rate-watch` user service in
        ~/.config/home-manager/aptx-adaptive/aptx-adaptive.nix.  An explicit
        `ad-ctl rate <hz>` overrides both.

        Note: the MOMENTUM 5 advertises 44.1 kHz with the 0x40 rate bit, while
        the encoder only recognises 0x08 for 44.1 kHz, so 44100 here falls back
        to 48000 with this headset.  A rate the peer does not offer is never
        selected.
      '';
    };

    capiBridge = {
      # The legacy path drives Qualcomm's CAPI encoder module through
      # qemu-hexagon.  It is kept because it works (213 kbps at a fixed 25 ms
      # period), but the clean-room encoder above is what the running
      # configuration uses: 427 kbps HQ / 270 kbps LL with native ABR.
      enable = lib.mkEnableOption
        "the legacy CAPI/qemu encoder bridge (disables W^X for two user services)";

      runtimeDir = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        example = "/home/user/aptx-adaptive-runtime/legacy-capi";
        description = ''
          Directory holding the Hexagon helper (`helper/aptx-lossless-helper`)
          and its sysroot (`sysroot/`) for the legacy CAPI bridge.  Required
          when `enable` is set; the clean-room encoder does not use it.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.capiBridge.enable || cfg.capiBridge.runtimeDir != null;
        message = ''
          services.pipewire.aptxAdaptive.capiBridge.runtimeDir must point at the
          directory with the Hexagon helper and sysroot when the legacy CAPI
          bridge is enabled.
        '';
      }
    ];

    services.pipewire.package = pipewire-aptx-adaptive;

    # The clean-room plugin reads exactly two variables; declaring them here
    # keeps the slot and the boot default explicit and reproducible.  Both match
    # the plugin's own defaults.
    #
    # Only the two services that host the legacy codec need the helper
    # environment.  Exporting it through environment.variables leaked the
    # encoder configuration, including diagnostic switches, into every process
    # of the system.
    systemd.user.services.pipewire.environment = lib.mkMerge [
      {
        APTX_ADAPTIVE_SLOT = "aptx";
        APTX_ADAPTIVE_DEFAULT_MODE = "hq";
        # The Adaptive codec's directory first, the passthrough copy of the
        # genuine aptX/aptX HD codec second.  Both come from this build, so the
        # paths follow every rebuild instead of going stale, and the plugin can
        # offer aptX/HD to headsets that do not negotiate Adaptive.
        SPA_PLUGIN_DIR = "${pipewire-aptx-adaptive}/lib/spa-0.2:${realAptxCodecDir}";
      }
      (lib.mkIf cfg.capiBridge.enable adaptiveEnv)
    ];
    systemd.user.services.wireplumber.environment = lib.mkMerge [
      {
        APTX_ADAPTIVE_SLOT = "aptx";
        APTX_ADAPTIVE_DEFAULT_MODE = "hq";
        SPA_PLUGIN_DIR = "${pipewire-aptx-adaptive}/lib/spa-0.2:${realAptxCodecDir}";
      }
      (lib.mkIf cfg.capiBridge.enable adaptiveEnv)
    ];
    # Use the WirePlumber build that matches the aptX Adaptive PipeWire.
    services.pipewire.wireplumber.package = wireplumber-aptx-adaptive;
    # Never inherit a fixed diagnostic CIE from the user manager.  The codec
    # must use the peer's negotiated stream on the AX210 path; fixed overrides
    # are only for explicit, out-of-band experiments.
    systemd.user.services.pipewire.serviceConfig = lib.mkMerge [
      { UnsetEnvironment = [ "APTX_ADAPTIVE_CONFIG_STREAM_HEX" ]; }
      # The legacy bridge spawns a qemu-hexagon process.  QEMU's TCG JIT needs
      # writable+executable pages, which the default hardening
      # (MemoryDenyWriteExecute=yes) blocks: the codec then fails to start with
      # "qemu_mprotect__osdep: mprotect failed: Permission denied" and the sink
      # stays silent.  The clean-room encoder needs no JIT, so W^X stays on
      # unless capiBridge.enable is set.
      #
      # RISK: with capiBridge.enable those two user services run without W^X
      # whether or not a stream is active (the hardening flag is static per
      # unit).
      (lib.mkIf cfg.capiBridge.enable { MemoryDenyWriteExecute = false; })
    ];
    systemd.user.services.wireplumber.serviceConfig = lib.mkMerge [
      { UnsetEnvironment = [ "APTX_ADAPTIVE_CONFIG_STREAM_HEX" ]; }
      (lib.mkIf cfg.capiBridge.enable { MemoryDenyWriteExecute = false; })
    ];

    services.pipewire.wireplumber.extraConfig."aptx-adaptive" = {
      "monitor.bluez.properties" = lib.mkMerge [
        { "bluez5.codecs" = [
          "sbc"
          "sbc_xq"
          "aac"
          "aac_eld"
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
        ]; }
        # The bluez5 monitor reads this once, at start-up, into the audio info
        # it offers the codec when it picks a configuration.  Unset, PipeWire's
        # own default (48000) applies.
        (lib.mkIf (cfg.defaultRate != null) {
          "bluez5.default.rate" = cfg.defaultRate;
        })
      ];
      # Do not fall back to the headset (HFP/CVSD) profile when anything opens
      # a capture stream: that silently downgrades aptX Adaptive to CVSD and
      # the A2DP stream stops (observed as ~2 kB/s and no audio).
      "wireplumber.settings" = {
        "bluetooth.autoswitch-to-headset-profile" = false;
      };
    };
  };
}
