{ pkgs, lib, ... }:

let
  # 共用官方 CUDA 13 栈。不同 Python ABI 只更换有原生扩展的 wheel，
  # 避免源码版 torch/triton 被间接依赖（包括测试依赖）重新引入。
  mlOverrides = pyFinal: pyPrev:
    let
      abi = builtins.replaceStrings [ "." ] [ "" ] pyFinal.python.pythonVersion;
      wheelSources314 = {
        torch = {
          name = "torch-2.12.0+cu130-cp314-cp314-manylinux_2_28_x86_64.whl";
          url = "https://download.pytorch.org/whl/cu130/torch-2.12.0%2Bcu130-cp314-cp314-manylinux_2_28_x86_64.whl";
          sha256 = "3ff7366f6919232f099ef702c3ebd3509c91ab37c367e408cb3799c6bed214a4";
        };
        torchaudio = {
          name = "torchaudio-2.11.0+cu130-cp314-cp314-manylinux_2_28_x86_64.whl";
          url = "https://download.pytorch.org/whl/cu130/torchaudio-2.11.0%2Bcu130-cp314-cp314-manylinux_2_28_x86_64.whl";
          sha256 = "378b49671b581114a2d25d40928f12a150872feadf11669a63f573e81c78019a";
        };
        cuda-bindings = {
          name = "cuda_bindings-13.0.3-cp314-cp314-manylinux_2_24_x86_64.manylinux_2_28_x86_64.whl";
          url = "https://files.pythonhosted.org/packages/7a/c4/a931a90ce763bd7d587e18e73e4ce246b8547c78247c4f50ee24efc0e984/cuda_bindings-13.0.3-cp314-cp314-manylinux_2_24_x86_64.manylinux_2_28_x86_64.whl";
          sha256 = "e93866465e7ff4b7ebdf711cf9cd680499cd875f992058c68be08d4775ac233d";
        };
        triton = {
          name = "triton-3.7.0-cp314-cp314-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl";
          url = "https://files.pythonhosted.org/packages/8f/af/9904ec6d3c93d9b24e5ec360445bbdf758b7f00bfbeedb89cb0eb64eb8bb/triton-3.7.0-cp314-cp314-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl";
          sha256 = "b9b85e72968a9d8bba5ddb24e9b64aaabaf48affb042f2755cb7cfa92b7531ce";
        };
      };
      wheelPython = pyFinal.python // {
        pkgs = pyFinal // {
          buildPythonPackage = attrs: pyFinal.buildPythonPackage (attrs //
            lib.optionalAttrs (abi == "314" && builtins.hasAttr attrs.pname wheelSources314) {
              src = pkgs.fetchurl wheelSources314.${attrs.pname};
            });
        };
      };
      wheels = import ./tts/wheels.nix { inherit pkgs; py = wheelPython; };
      torchvisionWheel = wheels.mkWheel {
        pname = "torchvision";
        version = "0.27.0";
        name = "torchvision-0.27.0+cu130-cp${abi}-cp${abi}-manylinux_2_28_x86_64.whl";
        url = "https://download.pytorch.org/whl/cu130/torchvision-0.27.0%2Bcu130-cp${abi}-cp${abi}-manylinux_2_28_x86_64.whl";
        sha256 = if abi == "314"
          then "74c2e33effcdad257800c178f87f22cff311efe7037568b3feae7b4e191ce209"
          else "afa4128f37066b83af9d426841a53147dd3c208efea893c93dc3eb6fa2af2287";
        dependencies = [ wheels.torch pyFinal.numpy pyFinal.pillow ];
      };
      transformersWheel = wheels.mkWheel {
        pname = "transformers";
        version = "4.57.3";
        name = "transformers-4.57.3-py3-none-any.whl";
        url = "https://files.pythonhosted.org/packages/6a/6b/2f416568b3c4c91c96e5a365d164f8a4a4a88030aa8ab4644181fdadce97/transformers-4.57.3-py3-none-any.whl";
        sha256 = "1x03f0gq8czk2iw8kqpnfwsish8knfn3cgb0j40qicai90x3azf7";
        dependencies = with pyFinal; [
          filelock wheels.hubWheel jinja2 numpy packaging pyyaml regex requests
          wheels.safetensorsWheel wheels.tokenizersWheel tqdm
        ];
      };
    in {
      torch = wheels.torch;
      torch-bin = wheels.torch;
      torchvision = torchvisionWheel;
      torchvision-bin = torchvisionWheel;
      torchaudio = wheels.torchaudio;
      torchaudio-bin = wheels.torchaudio;
      # 官方 OpenCV wheel 不含 CUDA；保留原 CUDA 版，不使用 CPU 替代品。
      opencv4 = pyPrev.opencv4;
      transformers = transformersWheel;
      tokenizers = wheels.tokenizersWheel;
      safetensors = wheels.safetensorsWheel;
      huggingface-hub = wheels.hubWheel;
    };
in
{
  # 恢复原有包集的 CUDA 功能。大型 ML 栈显式使用官方 wheels，
  # 不通过关闭全局 CUDA 来减少编译。
  nixpkgs.config.cudaSupport = true;

  # OCR 使用已有缓存的 Python 3.14 CUDA OpenCV；TTS 保持 Python 3.13。
  # 包装原模块而不复制其实现，兼容策略统一维护在此文件。
  disabledModules = [ ./latex-ocr.nix ];
  imports = [
    ({ config, pkgs, lib, ... }@args:
      let
        pythonPackages = pkgs.python314Packages;
      in
      import ./latex-ocr.nix (args // {
        pkgs = pkgs // {
          python3 = pkgs.python314;
          python3Packages = pythonPackages // {
            buildPythonApplication = attrs: pythonPackages.buildPythonApplication (attrs // {
              propagatedBuildInputs = lib.filter
                (dep: (dep.pname or "") != "pyside6")
                (attrs.propagatedBuildInputs or [ ]);
              makeWrapperArgs = (attrs.makeWrapperArgs or [ ]) ++ [
                "--prefix" "LD_LIBRARY_PATH" ":"
                "${pkgs.stdenv.cc.cc.lib}/lib:/run/opengl-driver/lib"
              ];
              postInstall = (attrs.postInstall or "") + ''
                site="$out/${pythonPackages.python.sitePackages}/pix2tex"
                # API 默认也优先 CUDA；显式 --no-cuda 仍可使用 CPU。
                substituteInPlace "$site/cli.py" \
                  --replace-fail "'no_cuda': True" "'no_cuda': False" \
                  --replace-fail "        self.args.device = 'cuda' if torch.cuda.is_available() and not self.args.no_cuda else 'cpu'" \
                  "        self.args.device = 'cuda' if torch.cuda.is_available() and not self.args.no_cuda else 'cpu'
                        print(f'[LaTeX OCR] compute device: {self.args.device}', file=sys.stderr)"
                substituteInPlace "$site/gui.py" \
                  --replace-fail 'self.setWindowTitle("LaTeX OCR")' \
                  'self.setWindowTitle(f"LaTeX OCR [{self.model.args.device.upper()}]")'
              '';
            });
          };
        };
      })
    )
  ];

  nixpkgs.overlays = [
    (_: prev: {
      python313 = prev.python313.override {
        packageOverrides = lib.composeExtensions
          (prev.python313.packageOverrides or (_: _: { })) mlOverrides;
      };
      python314 = prev.python314.override {
        packageOverrides = lib.composeExtensions
          (prev.python314.packageOverrides or (_: _: { })) mlOverrides;
      };

      # CUDA redist 旧 hook 合并传播数组，与新版 multiple-outputs 不兼容。
      cudaPackages_12_9 = prev.cudaPackages_12_9.overrideScope (_: cudaPrev:
        lib.genAttrs [
          "cuda_opencl"
          "cuda_cuxxfilt"
          "cuda_nvml_dev"
          "cuda_nvtx"
          "cuda_nvrtc"
          "cuda_cupti"
          "libnvjitlink"
          "libcufft"
          "libcublas"
          "libnpp"
          "libcusparse"
          "libcusolver"
          "libcurand"
          "nvcomp"
          "libcufile"
          "cudnn"
          "libcusparse_lt"
        ] (name:
          cudaPrev.${name}.overrideAttrs (old: {
            preFixup = (old.preFixup or "") + ''
              fixupPropagatedBuildOutputsForMultipleOutputs() {
                return 0
              }

              fixupCudaPropagatedBuildOutputsToOut() {
                local output
                mkdir -p "''${out:?}/nix-support"
                for output in "''${propagatedBuildOutputs[@]}"; do
                  nixLog "adding ''${!output:?} to propagatedBuildInputs of ''${out:?}"
                  printWords "''${!output:?}" >>"''${out:?}/nix-support/propagated-build-inputs"
                done
                return 0
              }
            '';
          })
        )
      );

      # 保留 -Werror，修复 SMPlayer 仅用于禁用调试日志的计数器警告。
      smplayer = prev.smplayer.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./script/smplayer-gcc16.patch ];
      });
    })
  ];

  # 保留 Joplin 3.7.18，避免当前渠道版本降级。
  programs.joplin-desktop.package = pkgs.joplin-desktop.overrideAttrs (finalAttrs: _: {
    version = "3.7.18";
    src = pkgs.fetchFromGitHub {
      owner = "laurent22";
      repo = "joplin";
      rev = "ce254820977ea3fb2559638f722960dfc60e1cb1";
      hash = "sha256-12ZRoEutQsNJlrPypNrsffeIj+2ekqB/s6HN9ks/+rU=";
      postFetch = ''
        # 与 nixpkgs 的源规范化一致，移除跨平台文件名不兼容的测试照片。
        find "$out/packages/app-cli/tests/support" -maxdepth 1 -type f -name 'photo*' -delete
      '';
    };
    missingHashes = ./script/joplin-missing-hashes.json;
    offlineCache = pkgs.yarn-berry_4.fetchYarnBerryDeps {
      inherit (finalAttrs) src missingHashes;
      hash = "sha256-W5hXh1i1rTe4OkhTvHPpDQgPSvRqTZ/GsJnHXE2D/2Y=";
    };
  });
}
