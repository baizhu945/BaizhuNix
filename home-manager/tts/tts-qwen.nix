{ config, pkgs, lib, ... }:

# ============================================================================
# 本地 TTS: Qwen3-TTS-12Hz-0.6B-CustomVoice (Alibaba Qwen) — 替代原 CosyVoice3
#   - LLM 驱动 (Qwen3-0.6B): 中英等多语言混读 (language=auto 自动语码切换),
#     解决 CosyVoice3 混读乱读问题
#   - 10 种语言: 中/英/日/韩/德/法/俄/葡/西/意 (+ 北京/四川方言音色)
#   - 9 个内置音色 (无需音色克隆), 纯 TTS
#   - 全链路预编译 wheel (见 wheels.nix): torch 2.12.0+cu130 官方
#     wheel + transformers/accelerate wheel, 零本地 CUDA 编译
#   - 模型权重 fetchurl 固定 sha256 声明式获取 (共约 2.5GB)
# 运行时需: NVIDIA 驱动 (libcuda) + libstdc++ (gcc-15)
# ============================================================================

let
  py = pkgs.python313;

  wheels = import ./wheels.nix { inherit pkgs py; };
  inherit (wheels) mkWheel torch torchaudio tokenizersWheel safetensorsWheel hubWheel;

  # --------------------------------------------------------------------------
  # qwen-tts 0.1.1 官方 pin: transformers==4.57.3 / accelerate==1.12.0
  # (transformers 核心依赖 tokenizers 0.22.2 / hub 0.34.2 / safetensors 0.8.0
  # 与 wheels.nix 完全兼容)
  # --------------------------------------------------------------------------
  transformersWheel = mkWheel {
    pname = "transformers";
    version = "4.57.3";
    name = "transformers-4.57.3-py3-none-any.whl";
    url = "https://files.pythonhosted.org/packages/6a/6b/2f416568b3c4c91c96e5a365d164f8a4a4a88030aa8ab4644181fdadce97/transformers-4.57.3-py3-none-any.whl";
    sha256 = "1x03f0gq8czk2iw8kqpnfwsish8knfn3cgb0j40qicai90x3azf7";
    dependencies = with py.pkgs; [
      filelock hubWheel jinja2 numpy packaging pyyaml regex requests
      safetensorsWheel tokenizersWheel tqdm
    ];
  };
  accelerateWheel = mkWheel {
    pname = "accelerate";
    version = "1.12.0";
    name = "accelerate-1.12.0-py3-none-any.whl";
    url = "https://files.pythonhosted.org/packages/9f/d2/c581486aa6c4fbd7394c23c47b83fa1a919d34194e16944241daf9e762dd/accelerate-1.12.0-py3-none-any.whl";
    sha256 = "04dvr83nwi6ydmys7wi6qc6jbkggn5a6cjh85xz208ql6k6r281y";
    dependencies = with py.pkgs; [ numpy packaging psutil pyyaml torch hubWheel safetensorsWheel ];
  };
  # python-sox (sdist 纯 python, 无编译): qwen_tts 25Hz 分词器路径 import 依赖
  # (实际只用 12Hz, 不会实例化; 找不到 sox 二进制仅警告)
  soxSdist = py.pkgs.buildPythonPackage {
    pname = "sox";
    version = "1.5.0";
    format = "setuptools";
    src = pkgs.fetchurl {
      name = "sox-1.5.0.tar.gz";
      url = "https://files.pythonhosted.org/packages/3d/a2/d8e0d8fd7abf509ead4a2cb0fb24e5758b5330166bf9223d5cb9f98a7e8d/sox-1.5.0.tar.gz";
      sha256 = "185dd4jfnnif11h8ya95w9s1s6jzrw42rs0izs8xhj7mn5dvxiqj";
    };
    doCheck = false;
    pythonImportsCheck = [ ];
    dependencies = with py.pkgs; [ numpy typing-extensions ];
  };

  # qwen-tts 源码 (pin rev + hash)
  qwenTtsSrc = pkgs.fetchFromGitHub {
    owner = "QwenLM";
    repo = "Qwen3-TTS";
    rev = "022e286b98fbec7e1e916cb940cdf532cd9f488e";
    sha256 = "1k9rapdyr7lawmn21vsbwa0zw42mfzdcm72zi0kw66cggncvsp6w";
  };

  pythonEnv = py.withPackages (ps: [
    torch
    torchaudio
    transformersWheel
    accelerateWheel
    soxSdist
    ps.einops
    ps.librosa
    ps.soundfile
    ps.onnxruntime
    ps.numpy
    ps.tqdm
  ]);

  # --------------------------------------------------------------------------
  # 模型权重 (Qwen3-TTS-12Hz-0.6B-CustomVoice, huggingface, sha256 固定)
  # --------------------------------------------------------------------------
  modelBase = "https://huggingface.co/Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice/resolve/main";
  modelFile = name: sha256: pkgs.fetchurl {
    inherit name sha256;
    url = "${modelBase}/${name}";
  };

  llmSafetensors = modelFile "model.safetensors" "1nrazb03amvvnspabwzj0809x0rzy37il3a54nf1fqdrbrw7wg5w";
  tokenizerSafetensors = modelFile "speech_tokenizer/model.safetensors" "0n0jayx31g8drx7gxkhsi18kgzldysd718rnk643x92ygwspnsw3";
  cfgJson = modelFile "config.json" "0mbl1hs2jixb4ar6cbifzkajg9x9v1r54d6gi96r8163zava5b41";
  genCfg = modelFile "generation_config.json" "1apk4x0z13ibr24ny9ziv905jk3v5m4y4j8hhmi4rczk2d2hpfgi";
  merges = modelFile "merges.txt" "1qzm4r78f3k12aycaix5qyy7qx5xsmjyiz9k2x5pg22h0xaap6sr";
  preproc = modelFile "preprocessor_config.json" "06f1y4dan1b1izq3gs36wji5p3qk74qxb73spwl6kmx95q1f3pgg";
  tokCfg = modelFile "tokenizer_config.json" "0w56whm9j1a5avxs9xaimmsnf0i3fghcpcrb70b51pdfpp1k2g6w";
  vocab = modelFile "vocab.json" "04098jqi03ps99l3jx7j6a710vf1g4jpl9qyvmsqbl9yzglxf46a";
  stCfg = modelFile "speech_tokenizer/config.json" "0rw1wq8w57gcnn7v4sarqrbyx9m1g8aqgi07hymn8rl73j8bnrgf";
  stConf = modelFile "speech_tokenizer/configuration.json" "1gffw1a4lagmy63rgmf9srb94hlbjmqj79dmvb8v892hxdj6vhkb";
  stPreproc = modelFile "speech_tokenizer/preprocessor_config.json" "1yxxzi15k6z0wa86fffkz104cll8cqpn0vkhcx06sy3yb5g81czw";

  models = pkgs.runCommand "qwen3-tts-0.6b-customvoice" { } ''
    mkdir -p $out/speech_tokenizer
    ln -s ${llmSafetensors} $out/model.safetensors
    ln -s ${tokenizerSafetensors} $out/speech_tokenizer/model.safetensors
    ln -s ${cfgJson} $out/config.json
    ln -s ${genCfg} $out/generation_config.json
    ln -s ${merges} $out/merges.txt
    ln -s ${preproc} $out/preprocessor_config.json
    ln -s ${tokCfg} $out/tokenizer_config.json
    ln -s ${vocab} $out/vocab.json
    ln -s ${stCfg} $out/speech_tokenizer/config.json
    ln -s ${stConf} $out/speech_tokenizer/configuration.json
    ln -s ${stPreproc} $out/speech_tokenizer/preprocessor_config.json
  '';

  # --------------------------------------------------------------------------
  # 客户端 (一次性模式: 用完即退出释放显存, 不常驻)
  # --------------------------------------------------------------------------
  runtimeLibs = lib.concatStringsSep ":" [
    "/run/opengl-driver/lib"
    "${pkgs.stdenv.cc.cc.lib}/lib"
  ];

  # flock 串行化: 并发调用会各自加载模型导致显存超限
  tts-core = pkgs.writeShellScriptBin "tts-core" ''
    export QWEN_TTS_MODEL_DIR=${models}
    export PYTHONPATH=${qwenTtsSrc}
    export XDG_CACHE_HOME=$HOME/.cache
    export HF_HOME=$HOME/.cache/huggingface
    export HF_HUB_OFFLINE=1
    export LD_LIBRARY_PATH=${runtimeLibs}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
    exec flock -w 900 "$HOME/.cache/qwen-tts.lock" \
      ${pythonEnv}/bin/python ${./tts-qwen-core.py} "$@"
  '';

  speak = pkgs.writeShellScriptBin "speak" ''
    exec ${tts-core}/bin/tts-core "$@"
  '';

  speak-file = pkgs.writeShellScriptBin "speak-file" ''
    if [ ! -f "$1" ]; then
      echo "Usage: speak-file <file>" >&2
      exit 1
    fi
    exec ${tts-core}/bin/tts-core < "$1"
  '';

  speak-clip = pkgs.writeShellScriptBin "speak-clip" ''
    if ! command -v wl-paste &>/dev/null; then
      echo "wl-paste not found, install wl-clipboard" >&2
      exit 1
    fi
    TEXT=$(wl-paste --no-newline 2>/dev/null)
    if [ -z "$TEXT" ]; then
      echo "Clipboard is empty" >&2
      exit 1
    fi
    echo "$TEXT" | ${tts-core}/bin/tts-core
  '';
in
{
  home.packages = [
    tts-core
    speak
    speak-file
    speak-clip
  ];
}
