{ config, pkgs, lib,  ... }:

let
  ollamaTarball =
    fetchTarball
      "https://github.com/NixOS/nixpkgs/archive/d6d0c1a3a42e5d56ba5065945a7351f99b8a7ffc.tar.gz";
in
{
  services.ollama = {
    enable = true;
    package = (import ollamaTarball {
      config = config.nixpkgs.config // { allowUnfree = true; };
      overlays = [
        (self: super: {
          ollama-cuda = super.ollama-cuda.overrideAttrs (oldAttrs:
            let
              inherit (super.cudaPackages) cuda_cudart libcublas cccl cuda_nvcc;
              inherit (super.lib) versions getLib getOutput getBin;
              cudaMajor = versions.major cuda_cudart.version;
              cudaToolkit = super.buildEnv {
                name = "cuda-merged-${cudaMajor}";
                paths = map getLib [ cuda_cudart libcublas cccl ] ++ [
                  (getOutput "static" cuda_cudart)
                  (getBin (cuda_nvcc.__spliced.buildHost or cuda_nvcc))
                ];
                ignoreCollisions = true;
              };
            in {
              preBuild = ''
                export CUDAToolkit_ROOT="${cudaToolkit}"
                for i in "''${!cmakeFlagsArray[@]}"; do
                  if [[ ''${cmakeFlagsArray[i]} == -DCUDAToolkit_ROOT=* ]]; then
                    cmakeFlagsArray[i]="-DCUDAToolkit_ROOT=${cudaToolkit}"
                  fi
                done
                cmakeFlags=''${cmakeFlagsArray[*]}
              '' + (oldAttrs.preBuild or "");
            }
          );
        })
      ];
    }).ollama-cuda;
    syncModels = true;
    loadModels = [
      # "deepseek-ocr:3b"
      "glm-ocr:bf16"
      "gemma4:12b"
    ];
  };

  nixpkgs.config = {
    cudaSupport = true;
  };

  environment.systemPackages = with pkgs; [
    cudaPackages.cudatoolkit
    cudaPackages.cuda_nvcc
    cudaPackages.nvcomp
    cudaPackages.nvidia_fs
    cudaPackages.cuda_opencl
    cudaPackages.cuda_cudart
  ];
}
