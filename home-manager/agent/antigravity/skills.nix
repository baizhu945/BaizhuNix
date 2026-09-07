{ pkgs, ... }:

let
  anbeime-skills-repo = pkgs.fetchgit {
    url = "https://github.com/anbeime/skill.git";
    rev = "b78cb5a8f5b3f26df9f9f0fcd26410a355ec7290";
    hash = "sha256-UHWZJ591F6GCvnpzUuG7zaAduIsEEbFuc/rwGOhUs0c=";
  };

  anthropics-skills-repo = pkgs.fetchgit {
    url = "https://github.com/anthropics/skills.git";
    rev = "41bbe19d1a1a7eaab5e7bb9050a417e5c6cffc8f";
    hash = "sha256-sjgPv9tZZVTXPxZWaCOc7JwFceNn3C1ghy8mSHqgqB8=";
  };

  agent-skills-repo = pkgs.fetchgit {
    url = "https://github.com/addyosmani/agent-skills.git";
    rev = "469d00f4e67ff4a21eb6e6e467a086c9a1f1deb8";
    hash = "sha256-kNj6pdQK6BK4bhozJbcEf7raYc+D2VLnGkm4bYEJlDs=";
  };
in
{
  programs.antigravity-cli.skills = {
    # ---- 本地技能（agent/skills/）----
    "cc-connect-cron" = ../skills/cc-connect-cron;
    "cc-connect-send" = ../skills/cc-connect-send;
    "chrome-automation" = ../skills/chrome-automation;

    # ---- anthropics/skills ----
    docx = "${anthropics-skills-repo}/skills/docx";
    pptx = "${anthropics-skills-repo}/skills/pptx";
    xlsx = "${anthropics-skills-repo}/skills/xlsx";
    pdf = "${anthropics-skills-repo}/skills/pdf";
    "canvas-design" = "${anthropics-skills-repo}/skills/canvas-design";

    # ---- anbeime/skill ----
    "media-processor" = "${anbeime-skills-repo}/skills/media-processor/media-processor";

    # ---- addyosmani/agent-skills ----
    "idea-refine" = "${agent-skills-repo}/skills/idea-refine";
  };
}
