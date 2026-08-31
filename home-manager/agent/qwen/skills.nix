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
in
{
  home.file = {
    # ---- 本地技能（agent/skills/）----
    ".qwen/skills/" = {
      source = ../skills;
      recursive = true;
    };

    # ---- anthropics/skills ----
    ".qwen/skills/docx".source = "${anthropics-skills-repo}/skills/docx";
    ".qwen/skills/pptx".source = "${anthropics-skills-repo}/skills/pptx";
    ".qwen/skills/xlsx".source = "${anthropics-skills-repo}/skills/xlsx";
    ".qwen/skills/pdf".source = "${anthropics-skills-repo}/skills/pdf";
    ".qwen/skills/canvas-design".source = "${anthropics-skills-repo}/skills/canvas-design";

    # ---- anbeime/skill ----
    ".qwen/skills/media-processor".source = "${anbeime-skills-repo}/skills/media-processor/media-processor";

    # ---- addyosmani/agent-skills ----
    ".qwen/skills/idea-refine".source = "${agent-skills-repo}/skills/idea-refine";
  };
}
