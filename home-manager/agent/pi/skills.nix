{ config, pkgs, lib, ... }:

let
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

  superpowers-plugin = builtins.fetchGit {
    url = "https://github.com/obra/superpowers.git";
    rev = "d884ae04edebef577e82ff7c4e143debd0bbec99";
  };
in
{
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
    ".pi/agent/skills/code-review-and-quality".source = "${agent-skills-repo}/skills/code-review-and-quality";
    ".pi/agent/skills/code-simplification".source = "${agent-skills-repo}/skills/code-simplification";
    ".pi/agent/skills/context-engineering".source = "${agent-skills-repo}/skills/context-engineering";
    ".pi/agent/skills/debugging-and-error-recovery".source = "${agent-skills-repo}/skills/debugging-and-error-recovery";
    ".pi/agent/skills/documentation-and-adrs".source = "${agent-skills-repo}/skills/documentation-and-adrs";
    ".pi/agent/skills/doubt-driven-development".source = "${agent-skills-repo}/skills/doubt-driven-development";
    ".pi/agent/skills/frontend-ui-engineering".source = "${agent-skills-repo}/skills/frontend-ui-engineering";
    ".pi/agent/skills/git-workflow-and-versioning".source = "${agent-skills-repo}/skills/git-workflow-and-versioning";
    ".pi/agent/skills/idea-refine".source = "${agent-skills-repo}/skills/idea-refine";
    ".pi/agent/skills/performance-optimization".source = "${agent-skills-repo}/skills/performance-optimization";
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
  };
}
