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
    url = "https://github.com/addyosmani/agent-skills.git";
    ref = "main";
  };

  superpowers-plugin = builtins.fetchGit {
    url = "https://github.com/obra/superpowers.git";
    rev = "d884ae04edebef577e82ff7c4e143debd0bbec99";
  };

  simulink-agentic-toolkit = builtins.fetchGit {
    url = "https://github.com/matlab/simulink-agentic-toolkit.git";
    rev = "054063b01ae0bdd72e2382e9f1969a7b50b35b4d";
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

      using-agent-skills = "${agent-skills-repo}/skills/using-agent-skills";
      api-and-interface-design = "${agent-skills-repo}/skills/api-and-interface-design";
      browser-testing-with-devtools = "${agent-skills-repo}/skills/browser-testing-with-devtools";
      ci-cd-and-automation = "${agent-skills-repo}/skills/ci-cd-and-automation";
      code-review-and-quality = "${agent-skills-repo}/skills/code-review-and-quality";
      code-simplification = "${agent-skills-repo}/skills/code-simplification";
      context-engineering = "${agent-skills-repo}/skills/context-engineering";
      debugging-and-error-recovery = "${agent-skills-repo}/skills/debugging-and-error-recovery";
      deprecation-and-migration = "${agent-skills-repo}/skills/deprecation-and-migration";
      documentation-and-adrs = "${agent-skills-repo}/skills/documentation-and-adrs";
      doubt-driven-development = "${agent-skills-repo}/skills/doubt-driven-development";
      frontend-ui-engineering = "${agent-skills-repo}/skills/frontend-ui-engineering";
      git-workflow-and-versioning = "${agent-skills-repo}/skills/git-workflow-and-versioning";
      idea-refine = "${agent-skills-repo}/skills/idea-refine";
      incremental-implementation = "${agent-skills-repo}/skills/incremental-implementation";
      interview-me = "${agent-skills-repo}/skills/interview-me";
      observability-and-instrumentation = "${agent-skills-repo}/skills/observability-and-instrumentation";
      performance-optimization = "${agent-skills-repo}/skills/performance-optimization";
      planning-and-task-breakdown = "${agent-skills-repo}/skills/planning-and-task-breakdown";
      security-and-hardening = "${agent-skills-repo}/skills/security-and-hardening";
      shipping-and-launch = "${agent-skills-repo}/skills/shipping-and-launch";
      source-driven-development = "${agent-skills-repo}/skills/source-driven-development";
      spec-driven-development = "${agent-skills-repo}/skills/spec-driven-development";
      test-driven-development = "${agent-skills-repo}/skills/test-driven-development";

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
      server = {
        port = 4096;
        hostname = "127.0.0.1";
        mdns = false;
      };

      # 插件配置
      plugin = [ 
        "opencode-title-gen"
        "superpowers"
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
    context = ./agent-context.md;
    
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
    ".config/opencode/plugins/superpowers.js".source = "${superpowers-plugin}/.opencode/plugins/superpowers.js";
    ".config/opencode/skills/superpowers".source = "${superpowers-plugin}/skills";

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
