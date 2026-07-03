{ config, pkgs, lib, ... }:

let
  opencodeTitleGenPlugin = let
    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/opencode-title-gen/-/opencode-title-gen-0.2.0.tgz";
      hash = "sha256-n5Wv/Iy/z3dr8TewAfM1bkBH6B3Qhql1qQrzwckDJEU=";
    };
  in 
  pkgs.runCommand "opencode-title-gen" {
    buildInputs = [ pkgs.gnutar pkgs.gzip ];
    LANG = "C.UTF-8";
    LC_ALL = "C.UTF-8";
  } ''
    mkdir -p $out
    tar -xzf ${src} -C $out --strip-components=1
    cp $out/dist/bundle.js $out/opencode-title-gen.js
  '';

  anbeime-skills-repo = builtins.fetchGit {
    url = "https://github.com/anbeime/skill.git";
    ref = "main";
  };

  anthropics-skills-repo = builtins.fetchGit {
    url = "https://github.com/anthropics/skills.git";
    ref = "main";
  };

  agent-skills-repo = builtins.fetchGit {
    url = "https://github.com/addyosmani/agent-skills";
    ref = "main";
  };

  simulink-agentic-toolkit = builtins.fetchGit {
    url = "https://github.com/matlab/simulink-agentic-toolkit.git";
    ref = "main";
  };
in 
{
  imports = [
    ./cc-connect.nix
  ];

  programs.opencode = {
    enable = true;

    # 使用 extraPackages 使 nodejs 可用（如果插件需要）
    extraPackages = with pkgs; [ nodejs ];

    skills = {
      tts-voice-synthesis = "${anbeime-skills-repo}/skills/tts-voice-synthesis";
      chrome-automation = "${anbeime-skills-repo}/skills/chrome-automation/chrome-automation";
      media-processor = "${anbeime-skills-repo}/skills/media-processor/media-processor";

      docx = "${anthropics-skills-repo}/skills/docx";
      pptx = "${anthropics-skills-repo}/skills/pptx";
      xlsx = "${anthropics-skills-repo}/skills/xlsx";
      pdf = "${anthropics-skills-repo}/skills/pdf";
      canvas-design = "${anthropics-skills-repo}/skills/canvas-design";

      agent-skills = "${agent-skills-repo}";

      building-simulink-models = "${simulink-agentic-toolkit}/skills-catalog/model-based-design-core/building-simulink-models";
      configuring-block-policy = "${simulink-agentic-toolkit}/skills-catalog/model-based-design-core/configuring-block-policy";
      curating-library-kg = "${simulink-agentic-toolkit}/skills-catalog/model-based-design-core/curating-library-kg";
      filing-bug-reports = "${simulink-agentic-toolkit}/skills-catalog/model-based-design-core/filing-bug-reports";
      generate-requirement-drafts = "${simulink-agentic-toolkit}/skills-catalog/model-based-design-core/generate-requirement-drafts";
      managing-simulink-projects = "${simulink-agentic-toolkit}/skills-catalog/model-based-design-core/managing-simulink-projects";
      setup-custom-libraries = "${simulink-agentic-toolkit}/skills-catalog/model-based-design-core/setup-custom-libraries";
      simulating-simulink-models = "${simulink-agentic-toolkit}/skills-catalog/model-based-design-core/simulating-simulink-models";
      specifying-mbd-algorithms = "${simulink-agentic-toolkit}/skills-catalog/model-based-design-core/specifying-mbd-algorithms";
      specifying-plant-models = "${simulink-agentic-toolkit}/skills-catalog/model-based-design-core/specifying-plant-models";
      testing-simulink-models = "${simulink-agentic-toolkit}/skills-catalog/model-based-design-core/testing-simulink-models";

      building-architecture-models = "${simulink-agentic-toolkit}/skills-catalog/model-based-system-engineering/building-architecture-models";
    };

    settings = {
      provider = {
        ollama = {
          npm = "@ai-sdk/openai-compatible";
          name = "Ollama (local)";
          options = {
            baseURL = "http://localhost:11434/v1";
          };
          models = {
            "gemma4:12b" = {
              name = "Gemma 4 12B (local)";
            };
          };
        };
      };

      server = {
        port = 4096;
        hostname = "127.0.0.1";
        mdns = false;
      };

      # 插件配置 - 参考 ~/.config/opencode/plugins/ 中的文件名（无 .js 后缀）
      plugin = [ 
        "opencode-title-gen"
        "superpowers@git+https://github.com/obra/superpowers.git"
      ];

      # 权限配置
      permission = {
        read = {
          "*" = "allow";
          "*.env" = "deny";
          "*.env.*" = "deny";
          "*.env.example" = "allow";
          "*.key" = "deny";
          "*.pem" = "deny";
          "id_rsa*" = "deny";
        };
        edit = "ask";
        glob = "allow";
        grep = "allow";
        bash = "ask";
        task = "allow";
        skill = "allow";
        webfetch = "allow";
        websearch = "allow";
        question = "allow";
        lsp = "allow";
      };

    };

    # 上下文配置
    context = ./context/context.md;
    
    tui = {
      theme = "system";
    };

    web = {
      enable = true;
      extraArgs = [ "--hostname" "127.0.0.1" "--port" "4096" ];
    };
  };

  home.file = {
    ".config/opencode/plugins/opencode-title-gen.js".source = "${opencodeTitleGenPlugin}/opencode-title-gen.js";

    ".config/opencode/smart-title.jsonc".text = ''
      {
        "mode": "continuous",
        "maxTurns": 5,
        "maxCharsPerPart": 300,
        "debounceMs": 1500
      }
    '';
  };
}
