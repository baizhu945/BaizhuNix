{ config, pkgs, lib,  ... }:

{
  # nixos-unstable 的 multiple-outputs 已支持数组，但 CUDA redist hook
  # 仍把 propagatedBuildOutputs 写成含空格的单个数组元素，导致
  # 多输出包构建时报 "include lib" / "bin include: invalid variable name"。
  # 仅覆盖本次需要构建的 12.9 多输出 redist，不替换公共 hook。
  # 上游移除旧转换并改为数组遍历后，可以删除此兼容覆盖。
  nixpkgs.overlays = [
    (final: prev: {
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
    })
  ];

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
