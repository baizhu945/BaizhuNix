# ============================================================================
# 共享 wheel 库: CUDA 预编译 torch 栈 (tts.nix 与 tts-qwen.nix 共用)
#   全部来自官方预编译 wheel (pypi.nvidia.com / download.pytorch.org /
#   files.pythonhosted.org), 无任何本地 CUDA 编译
# 注意: 修改任何 URL/sha256/依赖都会改变所有引用模块的 store 路径
# ============================================================================
{ pkgs, py }:
let
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

  # huggingface-hub <1.0 (transformers 4.5x 要求; nixpkgs 是 1.16)

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
  torchaudio = mkWheel {
    pname = "torchaudio";
    version = "2.11.0";
    name = "torchaudio-2.11.0+cu130-cp313-cp313-manylinux_2_28_x86_64.whl";
    url = "https://download.pytorch.org/whl/cu130/torchaudio-2.11.0%2Bcu130-cp313-cp313-manylinux_2_28_x86_64.whl";
    sha256 = "e9c07cfdab691454092ff12d21dd1407a4bb8ad081d38f222cf6fcf6abcc18c8";
    dependencies = [ torch ];
  };
in
{
  inherit mkWheel torch torchaudio tokenizersWheel safetensorsWheel hubWheel;
}
