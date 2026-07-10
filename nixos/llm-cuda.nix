{ config, pkgs, lib,  ... }:

let
  unstableTarball =
    fetchTarball
      "https://nixos.org/channels/nixpkgs-unstable/nixexprs.tar.xz";
  unstablePkgs = import unstableTarball {
    config = config.nixpkgs.config;
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
