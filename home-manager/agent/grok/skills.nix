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
    ".grok/skills/chrome-automation".source = ../skills/chrome-automation;

    # ---- anthropics/skills ----
    ".grok/skills/docx".source = "${anthropics-skills-repo}/skills/docx";
    ".grok/skills/pptx".source = "${anthropics-skills-repo}/skills/pptx";
    ".grok/skills/xlsx".source = "${anthropics-skills-repo}/skills/xlsx";
    ".grok/skills/pdf".source = "${anthropics-skills-repo}/skills/pdf";
  };
}
