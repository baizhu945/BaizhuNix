{ config, pkgs, lib,  ... }:

{
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    # Ollama 0.32 defaults to a 4096-token runtime context. Pi's system
    # prompt and tool definitions already exceed that, so use a 32K context
    # for OpenAI-compatible clients such as pi-coding-agent.
    environmentVariables = {
      OLLAMA_CONTEXT_LENGTH = "32768";
    };
    syncModels = true;
    loadModels = [
      "deepseek-ocr:3b"
      "ornith-1.5:9b"
    ];
  };

  systemd.services.ollama-create-gpu-models = {
    description = "Create GPU-limited Ollama models";
    wantedBy = [ "multi-user.target" ];
    after = [ "ollama.service" ];
    requires = [ "ollama.service" ];
    path = [ pkgs.ollama-cuda ];
    environment.HOME = "/var/lib/ollama";
    script = ''
      ollama list 2>/dev/null | grep -q 'deepseek-ocr:3b-gpu12' && exit 0
      cat > /tmp/deepseek-ocr-gpu12.Modelfile << 'EOF'
FROM deepseek-ocr:3b
PARAMETER num_gpu 12
EOF
      ollama create deepseek-ocr:3b-gpu12 -f /tmp/deepseek-ocr-gpu12.Modelfile
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "ollama";
      Group = "ollama";
    };
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
