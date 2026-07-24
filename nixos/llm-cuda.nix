{ config, pkgs, lib,  ... }:

let
  unstableTarball =
    fetchTarball
      "https://nixos.org/channels/nixpkgs-unstable/nixexprs.tar.xz";

  overlay = final: prev: {
    ollama-cuda = prev.ollama-cuda.overrideAttrs (oldAttrs:
      let
        cudaLibs = with prev.cudaPackages; [ cuda_cudart libcublas cccl ];
        cudaMajorVersion = prev.lib.versions.major prev.cudaPackages.cuda_cudart.version;
        cudaToolkit = prev.buildEnv {
          name = "cuda-merged-${cudaMajorVersion}";
          paths = map prev.lib.getLib cudaLibs ++ [
            (prev.lib.getOutput "static" prev.cudaPackages.cuda_cudart)
            (prev.lib.getBin (prev.cudaPackages.cuda_nvcc.__spliced.buildHost or prev.cudaPackages.cuda_nvcc))
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
  };

  unstablePkgs = import unstableTarball {
    config = config.nixpkgs.config // { allowUnfree = true; };
    overlays = [ overlay ];
  };
in
{
  services.ollama = {
    enable = true;
    package = unstablePkgs.ollama-cuda;
    syncModels = true;
    loadModels = [
      "deepseek-ocr"
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
