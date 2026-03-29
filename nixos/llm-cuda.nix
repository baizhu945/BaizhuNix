{ config, pkgs, lib,  ... }:

{
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    syncModels = true;
    loadModels = [
      "deepseek-ocr"
    ];
  };
  # services.open-webui = {
    # enable = true;
    # port = 8080;
    # host = "127.0.0.1";
    # environment = {
      # BYPASS_INSTALLATION_CHECK = "True";
      # OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
      # WEBUI_AUTH = "False"; 
    # };
  # };
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
    stable-diffusion-cpp-cuda
  ];
}
