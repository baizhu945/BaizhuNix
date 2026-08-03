{ config, pkgs, lib, ... }:

let
  # 与 opencode.nix / reasonix.nix 完全相同的技能来源
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

  simulink-agentic-toolkit = builtins.fetchGit {
    url = "https://github.com/matlab/simulink-agentic-toolkit.git";
    rev = "054063b01ae0bdd72e2382e9f1969a7b50b35b4d";
  };

  # opencode 通过 superpowers 插件挂载的 skills（pi 无插件机制，直接挂 skills 目录）
  superpowers-plugin = builtins.fetchGit {
    url = "https://github.com/obra/superpowers.git";
    rev = "d884ae04edebef577e82ff7c4e143debd0bbec99";
  };
in
{
  # 用 nixpkgs overlay 给 pi 打补丁：底部消费金额以人民币（¥）显示，而非美元（$）
  # 补丁见 cost-cny.patch；汇率由 currency-rate.ts 扩展实时抓取写入 PI_USD_CNY_RATE
  # （扩展不可用时回退到固定值 7.2）
  nixpkgs.overlays = [
    (final: prev: {
      pi-coding-agent = prev.pi-coding-agent.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./cost-cny.patch ];
      });
    })
  ];

  programs.pi-coding-agent = {
    enable = true;

    # 让技能脚本可用的 nodejs（与 opencode.nix 的 extraPackages 一致）
    extraPackages = with pkgs; [ nodejs ];

    # 全局 context：与 opencode.nix 使用同一个 agent-context.md
    # 模块会将其写入 ~/.pi/agent/AGENTS.md
    context = ../agent-context.md;

    settings = {
      # 项目级资源（.pi/settings.json、项目 skills 等）默认询问是否信任
      defaultProjectTrust = "ask";

      # 默认模型：DeepSeek V4 Flash
      # （defaultProvider 必须与 defaultModel 一起设置，模型解析器两者都需要）
      defaultProvider = "deepseek";
      defaultModel = "deepseek-v4-flash";
    };
  };

  # skills：pi 的全局技能根是 ~/.pi/agent/skills/，逐个软链（reasonix.nix 同款做法）
  # 权限 gate：~/.pi/agent/extensions/ 下的 .ts 会被 pi 自动发现并加载
  home.file = {
    # ---- 本地技能（agent/skills/）----
    ".pi/agent/skills/chrome-automation".source = ../skills/chrome-automation;
    ".pi/agent/skills/cc-connect-cron".source = ../skills/cc-connect-cron;
    ".pi/agent/skills/cc-connect-send".source = ../skills/cc-connect-send;

    # ---- anbeime/skill ----
    ".pi/agent/skills/media-processor".source = "${anbeime-skills-repo}/skills/media-processor/media-processor";

    # ---- anthropics/skills ----
    ".pi/agent/skills/docx".source = "${anthropics-skills-repo}/skills/docx";
    ".pi/agent/skills/pptx".source = "${anthropics-skills-repo}/skills/pptx";
    ".pi/agent/skills/xlsx".source = "${anthropics-skills-repo}/skills/xlsx";
    ".pi/agent/skills/pdf".source = "${anthropics-skills-repo}/skills/pdf";
    ".pi/agent/skills/canvas-design".source = "${anthropics-skills-repo}/skills/canvas-design";

    # ---- addyosmani/agent-skills ----
    ".pi/agent/skills/using-agent-skills".source = "${agent-skills-repo}/skills/using-agent-skills";
    ".pi/agent/skills/api-and-interface-design".source = "${agent-skills-repo}/skills/api-and-interface-design";
    ".pi/agent/skills/code-review-and-quality".source = "${agent-skills-repo}/skills/code-review-and-quality";
    ".pi/agent/skills/code-simplification".source = "${agent-skills-repo}/skills/code-simplification";
    ".pi/agent/skills/context-engineering".source = "${agent-skills-repo}/skills/context-engineering";
    ".pi/agent/skills/debugging-and-error-recovery".source = "${agent-skills-repo}/skills/debugging-and-error-recovery";
    ".pi/agent/skills/deprecation-and-migration".source = "${agent-skills-repo}/skills/deprecation-and-migration";
    ".pi/agent/skills/documentation-and-adrs".source = "${agent-skills-repo}/skills/documentation-and-adrs";
    ".pi/agent/skills/doubt-driven-development".source = "${agent-skills-repo}/skills/doubt-driven-development";
    ".pi/agent/skills/frontend-ui-engineering".source = "${agent-skills-repo}/skills/frontend-ui-engineering";
    ".pi/agent/skills/git-workflow-and-versioning".source = "${agent-skills-repo}/skills/git-workflow-and-versioning";
    ".pi/agent/skills/idea-refine".source = "${agent-skills-repo}/skills/idea-refine";
    ".pi/agent/skills/incremental-implementation".source = "${agent-skills-repo}/skills/incremental-implementation";
    ".pi/agent/skills/interview-me".source = "${agent-skills-repo}/skills/interview-me";
    ".pi/agent/skills/observability-and-instrumentation".source = "${agent-skills-repo}/skills/observability-and-instrumentation";
    ".pi/agent/skills/performance-optimization".source = "${agent-skills-repo}/skills/performance-optimization";
    ".pi/agent/skills/planning-and-task-breakdown".source = "${agent-skills-repo}/skills/planning-and-task-breakdown";
    ".pi/agent/skills/security-and-hardening".source = "${agent-skills-repo}/skills/security-and-hardening";
    ".pi/agent/skills/shipping-and-launch".source = "${agent-skills-repo}/skills/shipping-and-launch";
    ".pi/agent/skills/source-driven-development".source = "${agent-skills-repo}/skills/source-driven-development";
    ".pi/agent/skills/spec-driven-development".source = "${agent-skills-repo}/skills/spec-driven-development";
    ".pi/agent/skills/test-driven-development".source = "${agent-skills-repo}/skills/test-driven-development";

    # ---- matlab/simulink-agentic-toolkit ----
    ".pi/agent/skills/building-simulink-models".source = "${simulink-agentic-toolkit}/skills-catalog/model-based-design-core/building-simulink-models";
    ".pi/agent/skills/configuring-block-policy".source = "${simulink-agentic-toolkit}/skills-catalog/model-based-design-core/configuring-block-policy";
    ".pi/agent/skills/curating-library-kg".source = "${simulink-agentic-toolkit}/skills-catalog/model-based-design-core/curating-library-kg";
    ".pi/agent/skills/filing-bug-reports".source = "${simulink-agentic-toolkit}/skills-catalog/model-based-design-core/filing-bug-reports";
    ".pi/agent/skills/generate-requirement-drafts".source = "${simulink-agentic-toolkit}/skills-catalog/model-based-design-core/generate-requirement-drafts";
    ".pi/agent/skills/managing-simulink-projects".source = "${simulink-agentic-toolkit}/skills-catalog/model-based-design-core/managing-simulink-projects";
    ".pi/agent/skills/setup-custom-libraries".source = "${simulink-agentic-toolkit}/skills-catalog/model-based-design-core/setup-custom-libraries";
    ".pi/agent/skills/simulating-simulink-models".source = "${simulink-agentic-toolkit}/skills-catalog/model-based-design-core/simulating-simulink-models";
    ".pi/agent/skills/specifying-mbd-algorithms".source = "${simulink-agentic-toolkit}/skills-catalog/model-based-design-core/specifying-mbd-algorithms";
    ".pi/agent/skills/specifying-plant-models".source = "${simulink-agentic-toolkit}/skills-catalog/model-based-design-core/specifying-plant-models";
    ".pi/agent/skills/testing-simulink-models".source = "${simulink-agentic-toolkit}/skills-catalog/model-based-design-core/testing-simulink-models";
    ".pi/agent/skills/building-architecture-models".source = "${simulink-agentic-toolkit}/skills-catalog/model-based-system-engineering/building-architecture-models";

    # ---- obra/superpowers（opencode 的 superpowers 插件 skills）----
    # 跳过 test-driven-development：与 addyosmani/agent-skills 重名，保留前者
    ".pi/agent/skills/brainstorming".source = "${superpowers-plugin}/skills/brainstorming";
    ".pi/agent/skills/dispatching-parallel-agents".source = "${superpowers-plugin}/skills/dispatching-parallel-agents";
    ".pi/agent/skills/executing-plans".source = "${superpowers-plugin}/skills/executing-plans";
    ".pi/agent/skills/finishing-a-development-branch".source = "${superpowers-plugin}/skills/finishing-a-development-branch";
    ".pi/agent/skills/receiving-code-review".source = "${superpowers-plugin}/skills/receiving-code-review";
    ".pi/agent/skills/requesting-code-review".source = "${superpowers-plugin}/skills/requesting-code-review";
    ".pi/agent/skills/subagent-driven-development".source = "${superpowers-plugin}/skills/subagent-driven-development";
    ".pi/agent/skills/systematic-debugging".source = "${superpowers-plugin}/skills/systematic-debugging";
    ".pi/agent/skills/using-git-worktrees".source = "${superpowers-plugin}/skills/using-git-worktrees";
    ".pi/agent/skills/using-superpowers".source = "${superpowers-plugin}/skills/using-superpowers";
    ".pi/agent/skills/verification-before-completion".source = "${superpowers-plugin}/skills/verification-before-completion";
    ".pi/agent/skills/writing-plans".source = "${superpowers-plugin}/skills/writing-plans";
    ".pi/agent/skills/writing-skills".source = "${superpowers-plugin}/skills/writing-skills";

    # ---- 权限 gate：只读放行，写/执行询问用户 ----
    ".pi/agent/extensions/permission-gate.ts".source = ./permission-gate.ts;

    # ---- 实时汇率扩展：为打补丁的 footer 提供实时 USD→CNY 汇率 ----
    ".pi/agent/extensions/currency-rate.ts".source = ./currency-rate.ts;
  };
}
