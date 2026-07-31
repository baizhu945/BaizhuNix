{ config, lib, pkgs, ... }:

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
  programs.codex = {
    enable = true;
    context = ../agent-context.md;

    skills = {
      chrome-automation = ../skills/chrome-automation;
      
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
  };
}
