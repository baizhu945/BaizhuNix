{ pkgs, config, lib, ... }:

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
  programs.codex.skills = {
    # ---- 本地技能（agent/skills/）----
    cc-connect-cron= ../skills/cc-connect-cron;
    cc-connect-send = ../skills/cc-connect-send;
    chrome-automation = ../skills/chrome-automation;

    # ---- anthropics/skills ----
    docx = "${anthropics-skills-repo}/skills/docx";
    pptx = "${anthropics-skills-repo}/skills/pptx";
    xlsx = "${anthropics-skills-repo}/skills/xlsx";
    pdf = "${anthropics-skills-repo}/skills/pdf";
    canvas-design = "${anthropics-skills-repo}/skills/canvas-design";

    # ---- anbeime/skill ----
    media-processor = "${anbeime-skills-repo}/skills/media-processor/media-processor";

    # ---- addyosmani/agent-skills ----
    idea-refine = "${agent-skills-repo}/skills/idea-refine";
  };
}
