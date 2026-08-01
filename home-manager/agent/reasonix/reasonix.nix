{ config, pkgs, lib, ... }:

let
  # 与 codex.nix 相同的技能来源：本地 1 个，其余从 GitHub 拉取后链接
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

  # DeepSeek-Reasonix 无 nixpkgs 包，从 GitHub 源码构建。
  # 仓库默认分支 main-v2（Reasonix 1.0 Go 重写版），这里固定到最新 release 标签 v1.18.0。
  # 注：v1.18.0 与 desktop-v1.18.0 指向同一 commit，CLI 与 desktop 共用此源码（desktop 是仓库内的嵌套 Go module）。
  reasonix-src = pkgs.fetchFromGitHub {
    owner = "esengine";
    repo = "DeepSeek-Reasonix";
    rev = "v1.18.0";
    hash = "sha256-DlWO5/YJO5QIxKYqcqXiiwKy83V8knZ0fzGgY2zoJzw=";
  };

  reasonix = pkgs.buildGoModule rec {
    pname = "reasonix";
    version = "1.18.0";

    src = reasonix-src;

    vendorHash = "sha256-Byt7/DbSHZ+PJ8evWARRQHds/kyuydTyYH98pFwAxNY=";

    # go.mod: go 1.25.0 + toolchain go1.26.5
    # nixpkgs-unstable 的 go 正好是 1.26.5，且 buildGoModule 设置 GOTOOLCHAIN=local，无需联网下载 toolchain

    # 只构建 CLI 入口，其余 cmd 下的工具（plugin-example 等）不需要
    subPackages = [ "cmd/reasonix" ];

    # 与上游 Makefile 保持一致：CGO_ENABLED=0 产出单一静态二进制
    env = {
      CGO_ENABLED = "0";
    };

    # 注入版本号（对应 Makefile 的 -X main.version）
    ldflags = [
      "-s"
      "-w"
      "-X main.version=v${version}"
    ];

    doCheck = false;

    # 国内网络使用 goproxy.cn 拉取 Go 模块依赖（与 agent/cc-connect.nix 相同做法）
    overrideModAttrs = (_: {
      GOPROXY = "https://goproxy.cn,direct";
    });

    meta = {
      description = "DeepSeek-native AI coding agent for your terminal";
      homepage = "https://github.com/esengine/DeepSeek-Reasonix";
      license = lib.licenses.mit;
      mainProgram = "reasonix";
    };
  };

  # reasonix-desktop：Wails v2 桌面壳（嵌套 module reasonix/desktop，CGO + WebKitGTK）。
  # 构建方式与 nixpkgs 的 gui-for-singbox 相同：
  #   - frontend 用 pnpmConfigHook 单独构建出 dist（React+Vite，pnpm-lock.yaml lockfileVersion 9）
  #   - Go 侧用 wails CLI（nixpkgs 2.12.0，与 go.mod 的 wails/v2 v2.12.0 匹配）build，
  #     `-s` 跳过前端构建（dist 已复制），`-skipbindings` 跳过 wailsjs 生成
  #     （bridge.ts 对缺失的 wailsjs 用 @ts-ignore + drift-check fallback，tsc 仍通过），
  #     `-tags webkit2_41` 链接 WebKitGTK 4.1
  reasonix-desktop-frontend = pkgs.stdenv.mkDerivation {
    pname = "reasonix-desktop-frontend";
    version = "1.18.0";

    src = reasonix-src;

    sourceRoot = "source/desktop/frontend";

    nativeBuildInputs = [
      pkgs.nodejs
      pkgs.pnpmConfigHook
      pkgs.pnpm_10
    ];

    pnpmDeps = pkgs.fetchPnpmDeps {
      pname = "reasonix-desktop-frontend";
      version = "1.18.0";
      src = reasonix-src;
      sourceRoot = "source/desktop/frontend";
      pnpm = pkgs.pnpm_10;
      fetcherVersion = 3;
      hash = "sha256-leoj1tOwvIMX8C3y+KTcW6v+CXVlbm1M89Tikq8PkzQ=";
    };

    buildPhase = ''
      runHook preBuild
      pnpm run build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      cp -r dist $out
      runHook postInstall
    '';

    meta = {
      description = "Reasonix desktop frontend (React + Vite)";
      homepage = "https://github.com/esengine/DeepSeek-Reasonix";
      license = lib.licenses.mit;
    };
  };

  reasonix-desktop = pkgs.buildGoModule {
    pname = "reasonix-desktop";
    version = "1.18.0";

    src = reasonix-src;

    # 嵌套 module 位于仓库 desktop/ 目录
    modRoot = "desktop";

    vendorHash = "sha256-S0rsPFIWZ5Oa8gtvJIMV7pNXdI2Lh/GbAgx+c8qbzyo=";

    nativeBuildInputs = [
      pkgs.pkg-config
      pkgs.wails
      pkgs.wrapGAppsHook3
      pkgs.autoPatchelfHook
    ];

    buildInputs = [
      pkgs.glib-networking
      pkgs.webkitgtk_4_1
    ];

    # 国内网络使用 goproxy.cn 拉取 Go 模块依赖（与 CLI 相同做法）
    overrideModAttrs = (_: {
      GOPROXY = "https://goproxy.cn,direct";
    });

    preBuild = ''
      cp -r ${reasonix-desktop-frontend} frontend/dist
    '';

    buildPhase = ''
      runHook preBuild
      HOME=$TMPDIR wails build -m -s -trimpath -skipbindings -devtools -tags webkit2_41 -o reasonix-desktop
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      install -Dm0755 build/bin/reasonix-desktop "$out/bin/reasonix-desktop"
      install -Dm0644 build/appicon.png "$out/share/icons/hicolor/256x256/apps/reasonix-desktop.png"
      mkdir -p "$out/share/applications"
      cat > "$out/share/applications/reasonix-desktop.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Reasonix Desktop
Comment=Reasonix desktop — a Wails shell around the Go kernel
Exec=reasonix-desktop
Icon=reasonix-desktop
Categories=Development;Utility;
Terminal=false
StartupWMClass=reasonix-desktop
EOF
      runHook postInstall
    '';

    meta = {
      description = "Reasonix desktop — a Wails shell around the Reasonix Go kernel";
      homepage = "https://github.com/esengine/DeepSeek-Reasonix";
      license = lib.licenses.mit;
      mainProgram = "reasonix-desktop";
    };
  };
in
{
  home.packages = [
    reasonix
    reasonix-desktop
  ];

  # 与 codex 使用相同的 context 和 skills：
  # - context：AGENTS.md 不能软链（reasonix 拒绝指向 ~/.reasonix 之外的符号链接，
  #   instruction.document_symlink_escape），必须在 activation 中复制为真实文件
  # - skills：逐个软链进 ~/.reasonix/skills/<name>（reasonix 默认全局技能根，会跟随软链发现）
  home.file = {
    # 本地技能
    ".reasonix/skills/chrome-automation".source = ../skills/chrome-automation;
    ".reasonix/skills/cc-connect-cron".source = ../skills/cc-connect-cron;

    # anbeime/skill
    ".reasonix/skills/media-processor".source = "${anbeime-skills-repo}/skills/media-processor/media-processor";

    # anthropics/skills
    ".reasonix/skills/docx".source = "${anthropics-skills-repo}/skills/docx";
    ".reasonix/skills/pptx".source = "${anthropics-skills-repo}/skills/pptx";
    ".reasonix/skills/xlsx".source = "${anthropics-skills-repo}/skills/xlsx";
    ".reasonix/skills/pdf".source = "${anthropics-skills-repo}/skills/pdf";
    ".reasonix/skills/canvas-design".source = "${anthropics-skills-repo}/skills/canvas-design";

    # addyosmani/agent-skills
    ".reasonix/skills/using-agent-skills".source = "${agent-skills-repo}/skills/using-agent-skills";
    ".reasonix/skills/api-and-interface-design".source = "${agent-skills-repo}/skills/api-and-interface-design";
    ".reasonix/skills/browser-testing-with-devtools".source = "${agent-skills-repo}/skills/browser-testing-with-devtools";
    ".reasonix/skills/ci-cd-and-automation".source = "${agent-skills-repo}/skills/ci-cd-and-automation";
    ".reasonix/skills/code-review-and-quality".source = "${agent-skills-repo}/skills/code-review-and-quality";
    ".reasonix/skills/code-simplification".source = "${agent-skills-repo}/skills/code-simplification";
    ".reasonix/skills/context-engineering".source = "${agent-skills-repo}/skills/context-engineering";
    ".reasonix/skills/debugging-and-error-recovery".source = "${agent-skills-repo}/skills/debugging-and-error-recovery";
    ".reasonix/skills/deprecation-and-migration".source = "${agent-skills-repo}/skills/deprecation-and-migration";
    ".reasonix/skills/documentation-and-adrs".source = "${agent-skills-repo}/skills/documentation-and-adrs";
    ".reasonix/skills/doubt-driven-development".source = "${agent-skills-repo}/skills/doubt-driven-development";
    ".reasonix/skills/frontend-ui-engineering".source = "${agent-skills-repo}/skills/frontend-ui-engineering";
    ".reasonix/skills/git-workflow-and-versioning".source = "${agent-skills-repo}/skills/git-workflow-and-versioning";
    ".reasonix/skills/idea-refine".source = "${agent-skills-repo}/skills/idea-refine";
    ".reasonix/skills/incremental-implementation".source = "${agent-skills-repo}/skills/incremental-implementation";
    ".reasonix/skills/interview-me".source = "${agent-skills-repo}/skills/interview-me";
    ".reasonix/skills/observability-and-instrumentation".source = "${agent-skills-repo}/skills/observability-and-instrumentation";
    ".reasonix/skills/performance-optimization".source = "${agent-skills-repo}/skills/performance-optimization";
    ".reasonix/skills/planning-and-task-breakdown".source = "${agent-skills-repo}/skills/planning-and-task-breakdown";
    ".reasonix/skills/security-and-hardening".source = "${agent-skills-repo}/skills/security-and-hardening";
    ".reasonix/skills/shipping-and-launch".source = "${agent-skills-repo}/skills/shipping-and-launch";
    ".reasonix/skills/source-driven-development".source = "${agent-skills-repo}/skills/source-driven-development";
    ".reasonix/skills/spec-driven-development".source = "${agent-skills-repo}/skills/spec-driven-development";
    ".reasonix/skills/test-driven-development".source = "${agent-skills-repo}/skills/test-driven-development";

    # matlab/simulink-agentic-toolkit
    ".reasonix/skills/building-simulink-models".source = "${simulink-agentic-toolkit}/skills-catalog/model-based-design-core/building-simulink-models";
    ".reasonix/skills/configuring-block-policy".source = "${simulink-agentic-toolkit}/skills-catalog/model-based-design-core/configuring-block-policy";
    ".reasonix/skills/curating-library-kg".source = "${simulink-agentic-toolkit}/skills-catalog/model-based-design-core/curating-library-kg";
    ".reasonix/skills/filing-bug-reports".source = "${simulink-agentic-toolkit}/skills-catalog/model-based-design-core/filing-bug-reports";
    ".reasonix/skills/generate-requirement-drafts".source = "${simulink-agentic-toolkit}/skills-catalog/model-based-design-core/generate-requirement-drafts";
    ".reasonix/skills/managing-simulink-projects".source = "${simulink-agentic-toolkit}/skills-catalog/model-based-design-core/managing-simulink-projects";
    ".reasonix/skills/setup-custom-libraries".source = "${simulink-agentic-toolkit}/skills-catalog/model-based-design-core/setup-custom-libraries";
    ".reasonix/skills/simulating-simulink-models".source = "${simulink-agentic-toolkit}/skills-catalog/model-based-design-core/simulating-simulink-models";
    ".reasonix/skills/specifying-mbd-algorithms".source = "${simulink-agentic-toolkit}/skills-catalog/model-based-design-core/specifying-mbd-algorithms";
    ".reasonix/skills/specifying-plant-models".source = "${simulink-agentic-toolkit}/skills-catalog/model-based-design-core/specifying-plant-models";
    ".reasonix/skills/testing-simulink-models".source = "${simulink-agentic-toolkit}/skills-catalog/model-based-design-core/testing-simulink-models";
    ".reasonix/skills/building-architecture-models".source = "${simulink-agentic-toolkit}/skills-catalog/model-based-system-engineering/building-architecture-models";
  };

  # context：把 agent-context.md 复制为 ~/.reasonix/AGENTS.md（真实文件，每次 switch 刷新）
  home.activation.reasonixContext = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p "$HOME/.reasonix"
    $DRY_RUN_CMD install -m 600 ${../agent-context.md} "$HOME/.reasonix/AGENTS.md"
  '';
}
