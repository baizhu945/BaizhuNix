{ config, pkgs, lib, ... }:

# ============================================================================
# 本地 TTS: Fun-CosyVoice3-0.5B-2512 (FunAudioLLM)
#   - 9 种语言 (中/英/日/韩/德/西/法/意/俄) + 中英混读
#   - 指令控制情感/方言/语速/音量 (如 "请非常开心地说一句话"), 无需音色克隆
#   - 全链路预编译: torch 2.12.0+cu130 官方 wheel + nvidia-* cu13 wheel +
#     torchaudio/torchcodec wheel (与 pip install --index-url .../cu130 一致),
#     模型权重经 fetchurl 固定 sha256 声明式获取 (共约 10GB)
# 运行时需: NVIDIA 驱动 (libcuda) + libstdc++ (gcc-15) + FFmpeg 4 库 (torchcodec)
# ============================================================================

let
  py = pkgs.python313;

  mkWheel = { pname, version, name, url, sha256, dependencies ? [ ], passthru ? { } }: py.pkgs.buildPythonPackage {
    inherit pname version;
    format = "wheel";
    src = pkgs.fetchurl { inherit name url sha256; };
    doCheck = false;
    pythonImportsCheck = [ ];
    dontCheckRuntimeDeps = true; # wheel METADATA 依赖已全部自带/同环境
    inherit dependencies passthru;
  };

  cuda_toolkit = mkWheel {
    pname = "cuda-toolkit";
    version = "13.0.2";
    name = "cuda_toolkit-13.0.2-py2.py3-none-any.whl";
    url = "https://pypi.nvidia.com/cuda-toolkit/cuda_toolkit-13.0.2-py2.py3-none-any.whl";
    sha256 = "b198824cf2f54003f50d64ada3a0f184b42ca0846c1c94192fa269ecd97a66eb";
  };
  cuda_bindings = mkWheel {
    pname = "cuda-bindings";
    version = "13.0.3";
    name = "cuda_bindings-13.0.3-cp313-cp313-manylinux_2_24_x86_64.manylinux_2_28_x86_64.whl";
    url = "https://files.pythonhosted.org/packages/ab/ac/699889100536f1b63779646291e74eefa818087a0974eb271314d850f5dc/cuda_bindings-13.0.3-cp313-cp313-manylinux_2_24_x86_64.manylinux_2_28_x86_64.whl";
    sha256 = "512d0d803a5e47a8a42d5a34ce0932802bf72fe952fdb11ac798715a35c6e5cb";
  };
  nvidia_cublas = mkWheel {
    pname = "nvidia-cublas";
    version = "13.1.1.3";
    name = "nvidia_cublas-13.1.1.3-py3-none-manylinux_2_27_x86_64.whl";
    url = "https://pypi.nvidia.com/nvidia-cublas/nvidia_cublas-13.1.1.3-py3-none-manylinux_2_27_x86_64.whl";
    sha256 = "37936a16db8fe4ac1f065c2139360608a543a09275cb1a1af612e08cfa065436";
  };
  nvidia_cuda_cupti = mkWheel {
    pname = "nvidia-cuda-cupti";
    version = "13.0.85";
    name = "nvidia_cuda_cupti-13.0.85-py3-none-manylinux_2_25_x86_64.whl";
    url = "https://pypi.nvidia.com/nvidia-cuda-cupti/nvidia_cuda_cupti-13.0.85-py3-none-manylinux_2_25_x86_64.whl";
    sha256 = "4eb01c08e859bf924d222250d2e8f8b8ff6d3db4721288cf35d14252a4d933c8";
  };
  nvidia_cuda_nvrtc = mkWheel {
    pname = "nvidia-cuda-nvrtc";
    version = "13.0.88";
    name = "nvidia_cuda_nvrtc-13.0.88-py3-none-manylinux2010_x86_64.manylinux_2_12_x86_64.whl";
    url = "https://pypi.nvidia.com/nvidia-cuda-nvrtc/nvidia_cuda_nvrtc-13.0.88-py3-none-manylinux2010_x86_64.manylinux_2_12_x86_64.whl";
    sha256 = "ad9b6d2ead2435f11cbb6868809d2adeeee302e9bb94bcf0539c7a40d80e8575";
  };
  nvidia_cuda_runtime = mkWheel {
    pname = "nvidia-cuda-runtime";
    version = "13.0.96";
    name = "nvidia_cuda_runtime-13.0.96-py3-none-manylinux2014_x86_64.manylinux_2_17_x86_64.whl";
    url = "https://pypi.nvidia.com/nvidia-cuda-runtime/nvidia_cuda_runtime-13.0.96-py3-none-manylinux2014_x86_64.manylinux_2_17_x86_64.whl";
    sha256 = "7f82250d7782aa23b6cfe765ecc7db554bd3c2870c43f3d1821f1d18aebf0548";
  };
  nvidia_cudnn_cu13 = mkWheel {
    pname = "nvidia-cudnn-cu13";
    version = "9.20.0.48";
    name = "nvidia_cudnn_cu13-9.20.0.48-py3-none-manylinux_2_27_x86_64.whl";
    url = "https://pypi.nvidia.com/nvidia-cudnn-cu13/nvidia_cudnn_cu13-9.20.0.48-py3-none-manylinux_2_27_x86_64.whl";
    sha256 = "0c45dd8eeb50b603f07995b1b300c62ffe6a1980482b82b3bcf94a4ca9d49304";
  };
  nvidia_cufft = mkWheel {
    pname = "nvidia-cufft";
    version = "12.0.0.61";
    name = "nvidia_cufft-12.0.0.61-py3-none-manylinux2014_x86_64.manylinux_2_17_x86_64.whl";
    url = "https://pypi.nvidia.com/nvidia-cufft/nvidia_cufft-12.0.0.61-py3-none-manylinux2014_x86_64.manylinux_2_17_x86_64.whl";
    sha256 = "6c44f692dce8fd5ffd3e3df134b6cdb9c2f72d99cf40b62c32dde45eea9ddad3";
  };
  nvidia_cufile = mkWheel {
    pname = "nvidia-cufile";
    version = "1.15.1.6";
    name = "nvidia_cufile-1.15.1.6-py3-none-manylinux2014_x86_64.manylinux_2_17_x86_64.whl";
    url = "https://pypi.nvidia.com/nvidia-cufile/nvidia_cufile-1.15.1.6-py3-none-manylinux2014_x86_64.manylinux_2_17_x86_64.whl";
    sha256 = "08a3ecefae5a01c7f5117351c64f17c7c62efa5fffdbe24fc7d298da19cd0b44";
  };
  nvidia_curand = mkWheel {
    pname = "nvidia-curand";
    version = "10.4.0.35";
    name = "nvidia_curand-10.4.0.35-py3-none-manylinux_2_27_x86_64.whl";
    url = "https://pypi.nvidia.com/nvidia-curand/nvidia_curand-10.4.0.35-py3-none-manylinux_2_27_x86_64.whl";
    sha256 = "1aee33a5da6e1db083fe2b90082def8915f30f3248d5896bcec36a579d941bfc";
  };
  nvidia_cusolver = mkWheel {
    pname = "nvidia-cusolver";
    version = "12.0.4.66";
    name = "nvidia_cusolver-12.0.4.66-py3-none-manylinux_2_27_x86_64.whl";
    url = "https://pypi.nvidia.com/nvidia-cusolver/nvidia_cusolver-12.0.4.66-py3-none-manylinux_2_27_x86_64.whl";
    sha256 = "0a759da5dea5c0ea10fd307de75cdeb59e7ea4fcb8add0924859b944babf1112";
  };
  nvidia_cusparse = mkWheel {
    pname = "nvidia-cusparse";
    version = "12.6.3.3";
    name = "nvidia_cusparse-12.6.3.3-py3-none-manylinux2014_x86_64.manylinux_2_17_x86_64.whl";
    url = "https://pypi.nvidia.com/nvidia-cusparse/nvidia_cusparse-12.6.3.3-py3-none-manylinux2014_x86_64.manylinux_2_17_x86_64.whl";
    sha256 = "2b3c89c88d01ee0e477cb7f82ef60a11a4bcd57b6b87c33f789350b59759360b";
  };
  nvidia_cusparselt_cu13 = mkWheel {
    pname = "nvidia-cusparselt-cu13";
    version = "0.8.1";
    name = "nvidia_cusparselt_cu13-0.8.1-py3-none-manylinux2014_x86_64.whl";
    url = "https://pypi.nvidia.com/nvidia-cusparselt-cu13/nvidia_cusparselt_cu13-0.8.1-py3-none-manylinux2014_x86_64.whl";
    sha256 = "786ce87568c303fadb5afcc7102d454cd3040d75f6f8626f5db460d1871f4dd0";
  };
  nvidia_nccl_cu13 = mkWheel {
    pname = "nvidia-nccl-cu13";
    version = "2.29.7";
    name = "nvidia_nccl_cu13-2.29.7-py3-none-manylinux_2_18_x86_64.whl";
    url = "https://pypi.nvidia.com/nvidia-nccl-cu13/nvidia_nccl_cu13-2.29.7-py3-none-manylinux_2_18_x86_64.whl";
    sha256 = "edd81538446786ec3b73972543e53bb43bcaf0bfc8ef76cb679fcc390ffe136d";
  };
  nvidia_nvjitlink = mkWheel {
    pname = "nvidia-nvjitlink";
    version = "13.0.88";
    name = "nvidia_nvjitlink-13.0.88-py3-none-manylinux2010_x86_64.manylinux_2_12_x86_64.whl";
    url = "https://pypi.nvidia.com/nvidia-nvjitlink/nvidia_nvjitlink-13.0.88-py3-none-manylinux2010_x86_64.manylinux_2_12_x86_64.whl";
    sha256 = "13a74f429e23b921c1109976abefacc69835f2f433ebd323d3946e11d804e47b";
  };
  nvidia_nvshmem_cu13 = mkWheel {
    pname = "nvidia-nvshmem-cu13";
    version = "3.4.5";
    name = "nvidia_nvshmem_cu13-3.4.5-py3-none-manylinux2014_x86_64.manylinux_2_17_x86_64.whl";
    url = "https://pypi.nvidia.com/nvidia-nvshmem-cu13/nvidia_nvshmem_cu13-3.4.5-py3-none-manylinux2014_x86_64.manylinux_2_17_x86_64.whl";
    sha256 = "290f0a2ee94c9f3687a02502f3b9299a9f9fe826e6d0287ee18482e78d495b80";
  };
  nvidia_nvtx = mkWheel {
    pname = "nvidia-nvtx";
    version = "13.0.85";
    name = "nvidia_nvtx-13.0.85-py3-none-manylinux1_x86_64.manylinux_2_5_x86_64.whl";
    url = "https://pypi.nvidia.com/nvidia-nvtx/nvidia_nvtx-13.0.85-py3-none-manylinux1_x86_64.manylinux_2_5_x86_64.whl";
    sha256 = "4936d1d6780fbe68db454f5e72a42ff64d1fd6397df9f363ae786930fd5c1cd4";
  };
  triton = mkWheel {
    pname = "triton";
    version = "3.7.0";
    name = "triton-3.7.0-cp313-cp313-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl";
    url = "https://files.pythonhosted.org/packages/30/b1/b7507bb9815d403927c8dd51d4158ed2e11751a92dbc118a044f247b6848/triton-3.7.0-cp313-cp313-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl";
    sha256 = "a35d7afe3f3f058e7ec49fcce09794049e0ffc5c59019ac25ec3413741b8c4e7";
  };
  torch = mkWheel {
    pname = "torch";
    version = "2.12.0";
    name = "torch-2.12.0+cu130-cp313-cp313-manylinux_2_28_x86_64.whl";
    url = "https://download.pytorch.org/whl/cu130/torch-2.12.0%2Bcu130-cp313-cp313-manylinux_2_28_x86_64.whl";
    sha256 = "sha256-/l/vt4SjcNG6SVneboe807NUQQQKmb/+MvXNA7vINMA=";
    dependencies = [
      cuda_toolkit cuda_bindings
      nvidia_cublas nvidia_cuda_cupti nvidia_cuda_nvrtc nvidia_cuda_runtime
      nvidia_cudnn_cu13 nvidia_cufft nvidia_cufile nvidia_curand
      nvidia_cusolver nvidia_cusparse nvidia_cusparselt_cu13
      nvidia_nccl_cu13 nvidia_nvjitlink nvidia_nvshmem_cu13 nvidia_nvtx
      triton
    ] ++ (with py.pkgs; [ filelock fsspec jinja2 networkx numpy pyyaml requests setuptools sympy typing-extensions ]);
    passthru = {
      cudaSupport = true;
      cudaCapabilities = [ "12.0" ]; # RTX 5060 (GB206, Blackwell sm_120)
      cudaPackages = null; # 运行时 CUDA 库来自 nvidia-* wheel
      rocmSupport = false;
    };
  };

  # --------------------------------------------------------------------------
  # CosyVoice3 官方 pin 的版本 (实测 transformers 5.5.4/x-transformers 2.16.1/
  # diffusers 0.38 会产出乱码, 必须用 4.51.3/2.11.24/0.29.0)
  # --------------------------------------------------------------------------
  # huggingface-hub <1.0 (transformers 4.51 要求; nixpkgs 是 1.16)

  # tokenizers 0.22.2 (abi3 wheel; nixpkgs 版依赖 hub 1.16 会导致冲突)
  tokenizersWheel = mkWheel {
    pname = "tokenizers";
    version = "0.22.2";
    name = "tokenizers-0.22.2-cp39-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
    url = "https://files.pythonhosted.org/packages/2e/76/932be4b50ef6ccedf9d3c6639b056a967a86258c6d9200643f01269211ca/tokenizers-0.22.2-cp39-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
    sha256 = "369cc9fc8cc10cb24143873a0d95438bb8ee257bb80c71989e3ee290e8d72c67";
  };
  # safetensors 0.8.0 (abi3 wheel)
  safetensorsWheel = mkWheel {
    pname = "safetensors";
    version = "0.8.0";
    name = "safetensors-0.8.0-cp310-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
    url = "https://files.pythonhosted.org/packages/28/50/f203ff3a3ddfe19308efc83c5a3a29ed02bf786732ec35e68bf9162f3365/safetensors-0.8.0-cp310-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
    sha256 = "fd6f3f93c9a0a7cc2788ee63fb763353d4bd2e89b0751bc78fcf7dda00bea774";
  };
  hubWheel = mkWheel {
    pname = "huggingface-hub";
    version = "0.34.2";
    name = "huggingface_hub-0.34.2-py3-none-any.whl";
    url = "https://files.pythonhosted.org/packages/24/20/5ee412acef0af05bd3ccc78186ccb7ca672f9998a7cbc94c011df8f101f4/huggingface_hub-0.34.2-py3-none-any.whl";
    sha256 = "699843fc58d3d257dbd3cb014e0cd34066a56372246674322ba0909981ec239c";
    dependencies = with py.pkgs; [ filelock fsspec packaging pyyaml requests tqdm typing-extensions ];
  };
  # transformers 4.51.3 + 版本检查 patch (nixpkgs tokenizers 0.22.2 超出
  # 其 <0.22 上限, 实测 API 兼容, 仅绕过 ImportError 守卫)
  transformersWheel = (mkWheel {
    pname = "transformers";
    version = "4.51.3";
    name = "transformers-4.51.3-py3-none-any.whl";
    url = "https://files.pythonhosted.org/packages/a9/b6/5257d04ae327b44db31f15cce39e6020cc986333c715660b1315a9724d82/transformers-4.51.3-py3-none-any.whl";
    sha256 = "fd3279633ceb2b777013234bbf0b4f5c2d23c4626b05497691f00cfda55e8a83";
    dependencies = with py.pkgs; [
      filelock hubWheel numpy packaging pyyaml regex requests safetensorsWheel
      tokenizersWheel tqdm
    ];
  }).overrideAttrs (o: {
    postInstall = (o.postInstall or "") + ''
      # 绕过 tokenizers<0.22 的版本守卫 (0.22.2 API 实测兼容)
      sed -i "s/^def _compare_versions(op, got_ver, want_ver, requirement, pkg, hint):/def _compare_versions(op, got_ver, want_ver, requirement, pkg, hint):\\n    return True/" \
        $out/${py.sitePackages}/transformers/utils/versions.py
    '';
  });
  # x-transformers 2.11.24 (flow DiT 组件; 2.16.x 改 API 导致乱码)
  xTransformersWheel = mkWheel {
    pname = "x-transformers";
    version = "2.11.24";
    name = "x_transformers-2.11.24-py3-none-any.whl";
    url = "https://files.pythonhosted.org/packages/4a/ec/55d258e0b63c9269a72d535d7972c2524e173e3eac9f1627a9fd741f34bf/x_transformers-2.11.24-py3-none-any.whl";
    sha256 = "319d644d1bd4c6f2ada3a87c1367cf54013088d92b921b03e12c6ba03e97b81f";
    dependencies = with py.pkgs; [ einops einx loguru packaging torch ];
  };
  # diffusers 0.29.0 (matcha flow 的 attention 组件; 0.38 不兼容)
  diffusersWheel = mkWheel {
    pname = "diffusers";
    version = "0.29.0";
    name = "diffusers-0.29.0-py3-none-any.whl";
    url = "https://files.pythonhosted.org/packages/d5/68/a84d929518c9fbd65febcedd7810203bcac393f9cddd0603ec58df7f93f7/diffusers-0.29.0-py3-none-any.whl";
    sha256 = "4c194d2379644a0f7ef9b4ff12c8cf5de4c6324e811265754f08e2f839b8cedb";
    dependencies = with py.pkgs; [
      importlib-metadata filelock hubWheel numpy pillow pyyaml regex requests safetensorsWheel
    ];
  };
  torchaudio = mkWheel {
    pname = "torchaudio";
    version = "2.11.0";
    name = "torchaudio-2.11.0+cu130-cp313-cp313-manylinux_2_28_x86_64.whl";
    url = "https://download.pytorch.org/whl/cu130/torchaudio-2.11.0%2Bcu130-cp313-cp313-manylinux_2_28_x86_64.whl";
    sha256 = "e9c07cfdab691454092ff12d21dd1407a4bb8ad081d38f222cf6fcf6abcc18c8";
      dependencies = [ torch ];
  };
  torchcodec = mkWheel {
    pname = "torchcodec";
    version = "0.14.0";
    name = "torchcodec-0.14.0-cp313-cp313-manylinux_2_28_x86_64.whl";
    url = "https://files.pythonhosted.org/packages/e3/c1/7526ce7c76e4cc2958ee483755a2a77cfa21980cba34802e9033f5dc1a41/torchcodec-0.14.0-cp313-cp313-manylinux_2_28_x86_64.whl";
    sha256 = "77855d6969f33e82e5ff84445afdd4b68ba8a337e02b3c91229889eca988a004";
    dependencies = [ torch ];
  };

  withTorch = pkg: (pkg.override { torch = torch; }).overrideAttrs (o: {
    pythonImportsCheck = [ ];
    # 沙箱内无法加载 GPU 库 (libcudart/libstdc++), 跳过 pytest/import 检查
    dontUsePytestCheck = true;
  });
  # whisper 的 triton 依赖统一为 torch 同款预编译 triton wheel
  whisper = ps: (ps.openai-whisper.override { torch = torch; triton = triton; }).overrideAttrs (o: {
    pythonImportsCheck = [ ];
    dontUsePytestCheck = true;
  });
  # lightning (matcha 依赖 lightning.pytorch.utilities) — 通过 pytorch-lightning 传 torch
  lightning = ps: (ps.lightning.override {
    pytorch-lightning = (ps.pytorch-lightning.override { torch = torch; }).overrideAttrs (o: {
      pythonImportsCheck = [ ];
      dontUsePytestCheck = true;
    });
  }).overrideAttrs (o: {
    pythonImportsCheck = [ ];
    dontUsePytestCheck = true;
  });

  # conformer 未收录于 nixpkgs → 固定 wheel (Matcha-TTS flow 组件依赖)
  conformer = py.pkgs.buildPythonPackage {
    pname = "conformer";
    version = "0.3.2";
    format = "wheel";
    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/3f/7d/714601ab8d790d77d4158af743895fb999216cb02fc6283ab8e54911a887/conformer-0.3.2-py3-none-any.whl";
      sha256 = "b957faa683e9e75061257f77407318428f2ad0fb5262bfc2e9b55fc2fffdfa03";
    };
    doCheck = false;
    pythonImportsCheck = [ ];
    dependencies = [ py.pkgs.einops torch ];
  };

  # --------------------------------------------------------------------------
  # 源码 (pin rev + hash)
  # --------------------------------------------------------------------------
  cosyvoiceSrc = pkgs.fetchFromGitHub {
    owner = "FunAudioLLM";
    repo = "CosyVoice";
    rev = "074ca6dc9e80a2f424f1f74b48bdd7d3fea531cc";
    sha256 = "075s4vslhl4dm6szxcq0a9iykjd369f46v3cixz1lzx31jdq541n";
  };

  matchaSrc = pkgs.fetchFromGitHub {
    owner = "shivammehta25";
    repo = "Matcha-TTS"; # CosyVoice 的 git 子模块 (flow 模型组件)
    rev = "dd9105b34bf2be2230f4aa1e4769fb586a3c824e";
    sha256 = "0visb1xwsmfz16sm587b36hdg5hvyd825h6khy7xygbdawam3rcs";
  };

  pythonEnv = py.withPackages (ps: [
    torch
    torchcodec
    torchaudio
    conformer
    transformersWheel
    ps.hyperpyyaml
    xTransformersWheel
    diffusersWheel
    ps.omegaconf
    ps.hydra-core
    ps.gdown
    ps.matplotlib
    ps.rich
    ps.wget
    ps.pyarrow
    # pyworld 仅用 pkg_resources 取版本号 (setuptools 83 已移除), 直接替换
    (ps.pyworld.overrideAttrs (o: {
      pythonImportsCheck = [ ];
      postPatch = (o.postPatch or "") + ''
        substituteInPlace pyworld/__init__.py \
          --replace-fail "import pkg_resources" "import sys as _unused_pkg_resources" \
          --replace-fail "pkg_resources.get_distribution('pyworld').version" "'0.3.5'"
      '';
    }))
    (whisper ps)
    ps.onnxruntime
    (ps.modelscope.overrideAttrs (o: { postInstall = (o.postInstall or "") + " rm -rf $out/bin"; }))
    ps.inflect
    ps.librosa
    ps.soundfile
    ps.jieba
    ps.pypinyin
    ps.tiktoken
    tokenizersWheel
    ps.numpy
    ps.scipy
    ps.tqdm
    ps.pyyaml
    ps.fastapi
    ps.uvicorn
    ps.requests
    (lightning ps)
    ps.einops
  ]);

  # --------------------------------------------------------------------------
  # 模型权重 (Fun-CosyVoice3-0.5B-2512, modelscope, sha256 固定)
  # --------------------------------------------------------------------------
  modelBase = "https://modelscope.cn/models/FunAudioLLM/Fun-CosyVoice3-0.5B-2512/resolve/master";
  modelFile = name: sha256: pkgs.fetchurl {
    inherit name sha256;
    url = "${modelBase}/${name}";
  };

  llmPt = modelFile "llm.pt" "69f43bd545131c30e98947fb360ea8b4dc9916d8e83dded7757c7ea4f5a24970";
  flowPt = modelFile "flow.pt" "a6fab32a7825e5b0bc855ddd948f8db9370b0a786fbc249caa4595e95b608e4b";
  speechTok = modelFile "speech_tokenizer_v3.onnx" "23236a74175dbdda47afc66dbadd5bcb41303c467a57c261cb8539ad9db9208d";
  hiftPt = modelFile "hift.pt" "b279d7641eb97ae55b3b540cfba4f953c26492a2df758328a89a4d007ab87a65";
  campplus = modelFile "campplus.onnx" "a6ac6a63997761ae2997373e2ee1c47040854b4b759ea41ec48e4e42df0f4d73";
  yaml = modelFile "cosyvoice3.yaml" "f5a6b2c6f05139d0f18861a1fe506f751e787026b77c05f7e8fef9f8a4405965";
  cfgJson = modelFile "configuration.json" "c502b6328c67638b401df8dd05de89e9e8d1cff9cd0ada10dfbdbe13556c20de";

  blankCfg = modelFile "CosyVoice-BlankEN/config.json" "168aa1bd401abc3bc262ba15ba4e499627a8b4e006e9d050b47c22de20660185";
  blankGen = modelFile "CosyVoice-BlankEN/generation_config.json" "e558847a8b4402616f1273797b015104dc266fe4b520056fca88823ba8f8ebe6";
  blankMerges = modelFile "CosyVoice-BlankEN/merges.txt" "ac8ff86a72bee70828fbc1119bc4398c6f3a9a6e490d7b0dbe917be025478bd0";
  blankSafetensors = modelFile "CosyVoice-BlankEN/model.safetensors" "130282af0dfa9fe5840737cc49a0d339d06075f83c5a315c3372c9a0740d0b96";
  blankTokCfg = modelFile "CosyVoice-BlankEN/tokenizer_config.json" "482bd979881423375ca5414e4e0d94cd7c5349dbb17fffd46b4d36d71e62a1bc";
  blankVocab = modelFile "CosyVoice-BlankEN/vocab.json" "ca10d7e9fb3ed18575dd1e277a2579c16d108e32f27439684afa0e10b1440910";

  models = pkgs.runCommand "cosyvoice3-0.5b-2512" { } ''
    mkdir -p $out/CosyVoice-BlankEN
    ln -s ${llmPt} $out/llm.pt
    ln -s ${flowPt} $out/flow.pt
    ln -s ${speechTok} $out/speech_tokenizer_v3.onnx
    ln -s ${hiftPt} $out/hift.pt
    ln -s ${campplus} $out/campplus.onnx
    cp ${yaml} $out/cosyvoice3.yaml
    cp ${cfgJson} $out/configuration.json
    ln -s ${blankCfg} $out/CosyVoice-BlankEN/config.json
    ln -s ${blankGen} $out/CosyVoice-BlankEN/generation_config.json
    ln -s ${blankMerges} $out/CosyVoice-BlankEN/merges.txt
    ln -s ${blankSafetensors} $out/CosyVoice-BlankEN/model.safetensors
    ln -s ${blankTokCfg} $out/CosyVoice-BlankEN/tokenizer_config.json
    ln -s ${blankVocab} $out/CosyVoice-BlankEN/vocab.json
  '';

  # --------------------------------------------------------------------------
  # 客户端 (一次性模式: 用完即退出释放显存, 不常驻)
  # --------------------------------------------------------------------------
  # 运行时动态库: NVIDIA 驱动 (libcuda) + gcc-15 libstdc++ (torch/onnxruntime
  # 需要 GLIBCXX_3.4.34+) + FFmpeg 4 (torchcodec wheel 依赖 libavutil.so.56)
  runtimeLibs = lib.concatStringsSep ":" [
    "/run/opengl-driver/lib"
    "${pkgs.stdenv.cc.cc.lib}/lib"
    "${pkgs.ffmpeg_4.lib}/lib"
  ];

  # flock 串行化: 并发调用会各自加载模型导致显存超限 (2×~4.5GB > 8GB)
  tts-core = pkgs.writeShellScriptBin "tts-core" ''
    export COSYVOICE_MODEL_DIR=${models}
    export COSYVOICE_PROMPT_WAV=${cosyvoiceSrc}/asset/zero_shot_prompt.wav
    export PYTHONPATH=${cosyvoiceSrc}:${matchaSrc}
    export XDG_CACHE_HOME=$HOME/.cache
    export LD_LIBRARY_PATH=${runtimeLibs}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
    exec flock -w 900 "$HOME/.cache/cosyvoice-tts.lock" \
      ${pythonEnv}/bin/python ${./tts-core.py} "$@"
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
