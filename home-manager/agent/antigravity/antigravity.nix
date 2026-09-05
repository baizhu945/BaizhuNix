{ pkgs, ... }:

let
  superpowers-repo = builtins.fetchGit {
    url = "https://github.com/obra/superpowers.git";
    ref = "main";
  };

  # upstream 是 Gemini 扩展格式；Antigravity 原生插件需要根目录 plugin.json
  # 和 hooks.json，因此仅补齐 manifest/layout，实际 skills/hooks 仍直接来自上游。
  superpowers-plugin-manifest = pkgs.writeText "superpowers-plugin.json" (builtins.toJSON {
    "$schema" = "https://antigravity.google/schemas/v1/plugin.json";
    name = "superpowers";
    description = "Core skills library: TDD, debugging, collaboration patterns, and proven techniques";
  });

  superpowers-plugin = pkgs.symlinkJoin {
    name = "antigravity-superpowers-plugin";
    paths = [
      superpowers-repo
      (pkgs.linkFarm "antigravity-superpowers-plugin-files" [
        {
          name = "plugin.json";
          path = superpowers-plugin-manifest;
        }
        {
          name = "hooks.json";
          path = "${superpowers-repo}/hooks/hooks.json";
        }
      ])
    ];
  };
in
{
  imports = [
    ./skills.nix
  ];

  programs.antigravity-cli = {
    enable = true;
    package = pkgs.antigravity-cli;

    # Antigravity 使用 GEMINI.md 作为全局规则文件；内容与 Pi 的
    # ~/.pi/agent/AGENTS.md 相同。
    context = {
      GEMINI = ../agent-context.md;
    };

    settings = {
      # 保留现有 CLI 偏好，同时将其纳入声明式配置。
      allowNonWorkspaceAccess = true;
      artifactReviewPolicy = "agent-decides";
      colorScheme = "colorblind-friendly dark";
      enableTelemetry = false;
      model = "Gemini 3.8 Flash (High)";
      notifications = true;
      runningLightSpeed = "fast";
      statusLine = {
        type = "";
        command = "";
        enabled = true;
      };
      trustedWorkspaces = [ "/home/<yourusername>" ];

      # 确保上面的 GEMINI.md 是 Antigravity 的全局 context 文件。
      context.fileName = [ "GEMINI.md" ];
    };
  };

  # 该文件此前由 CLI 创建；现在由上面的 settings 声明接管。
  home.file.".gemini/antigravity-cli/settings.json".force = true;

  # 声明式安装 Superpowers；目录内容来自固定 revision 的只读 Nix store。
  home.file.".gemini/antigravity-cli/plugins/superpowers" = {
    source = superpowers-plugin;
    recursive = true;
    force = true;
  };
}
