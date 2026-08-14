{ config, pkgs, lib, ... }:

# ─────────────────────────────────────────────────────────────────────────────
# dsh — DeepSeek Harness(插件化 AI agent 平台,由 DeepSeek AI 官方开源)
#
# 安装方式:直接从 GitHub 源码声明式构建(固定 rev + 两个 hash),全量构建
# 包含 CLI(web / headless 两种 profile)与 Web 前端(React),无需 npm install。
#
# 本模块默认"只安装、零额外配置"。
# context / skills 的配置入口已在下文预留(见 home.file 与注释),按需取消注释即可。
# ─────────────────────────────────────────────────────────────────────────────

let
  # 源码固定版本(deepseek-harness master @ 47f9438,对应 npm 0.1.0-rc.x)
  dshSrc = pkgs.fetchFromGitHub {
    owner = "deepseek-ai";
    repo = "deepseek-harness";
    rev = "47f943859bef60e4160492346772ded9b24f765a";
    hash = "sha256-ZPGCNoPXVjP76Tm/tFPDX2X95cd83M4iHLmVP5dR+Ps=";
  };

  # 声明式 pnpm 依赖(fetchPnpmDeps 为 fixed-output 派生,沙箱内可联网下载;
  # hash 由仓库自带 pnpm-lock.yaml 固定,升级源码后需重新 prefetch)
  dshPnpmDeps = pkgs.fetchPnpmDeps {
    pname = "dsh";
    src = dshSrc;
    fetcherVersion = 4; # 26.11 起 pnpm_11 仅支持 fetcherVersion 4
    hash = "sha256-oCh1BpS9K+tyzN+x1HXTNHi/D0tirLbuskiX7wyGlBA=";
  };

  dsh = pkgs.stdenv.mkDerivation {
    pname = "dsh";
    version = "0.1.0-rc.5";
    src = dshSrc;

    pnpmDeps = dshPnpmDeps;

    # 前端展示补丁:进行中的工具调用/命令执行/思考过程默认展开,
    # 已结束的保持默认折叠(expand-running.patch 修改 ToolRow / ReasoningRow)
    # 审批弹窗补丁:新增第三个选项"总是允许(always-allow)",选择后写入会话日志,
    # 本次对话的所有写/执行默认放行(approval-always-allow.patch)
    # headless 补丁(cc-connect 集成):headless runner 新增 --session-id /
    # --model / --mode 三个选项,使 cc-connect 的 agent/dsh 可以跨轮次恢复同一
    # 个持久化会话、切换模型与权限模式(headless-cc-connect.patch 修改
    # packages/bundle/headless 的 startup.ts / index.ts / cordis.patch.yml)
    patches = [
      ./patches/expand-running.patch
      ./patches/approval-always-allow.patch
      ./patches/headless-cc-connect.patch
    ];

    nativeBuildInputs = [
      pkgs.nodejs_22 # dsh engines 要求 ^22.19 || >=24
      pkgs.pnpm_11   # 与仓库 packageManager 一致的 pnpm 11
      pkgs.pnpmConfigHook # 离线恢复 pnpm store 并执行 pnpm install
      pkgs.python3   # node-gyp 编译 node-pty 原生模块所需
      pkgs.node-gyp
    ];

    __structuredAttrs = true;
    strictDeps = true;

    # pnpm 默认隔离式 node_modules,dsh 的插件 loader(vendor/loader)运行时动态
    # import '@deepseek-ai/*',需要扁平布局(与 npm 发布版行为一致)
    pnpmInstallFlags = [ "--shamefully-hoist" ];

    postPatch = ''
      # pnpm 11 在每次 `pnpm run` 前验证 node_modules,与 --shamefully-hoist 冲突
      echo 'verifyDepsBeforeRun: false' >> pnpm-workspace.yaml
    '';

    # 全量构建:host/client 双面 tsc + tsdown 打包,以及 web 前端 vite build
    buildPhase = ''
      runHook preBuild
      # node-pty 的 pty.node 由 install script 用 node-gyp 编译(--ignore-scripts 跳过)
      cd node_modules/node-pty && node-gyp rebuild && cd ../..
      npm run build
      runHook postBuild
    '';

    # 产物 = 完整源码树 + node_modules(运行时经扁平链接加载 @deepseek-ai/* 插件)
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r . $out/
      # dsh 的 HMR/loader 需要访问 node 内部模块(--expose-internals),
      # 而 node-addon-require-builtin 的 prebuilt 与当前 node 版本不兼容,故用 wrapper 启动
      mkdir -p $out/bin
      cat > $out/bin/dsh <<EOF
      #!/bin/sh
      exec ${pkgs.nodejs_22}/bin/node --expose-internals $out/apps/cli/lib/bin.js "\$@"
      EOF
      chmod +x $out/bin/dsh
      # 恢复 node-pty 预编译 spawn-helper 的可执行位(--ignore-scripts 跳过 postinstall)
      find $out/node_modules/node-pty -name "spawn-helper" -exec chmod 755 {} + 2>/dev/null || true
      runHook postInstall
    '';

    dontFixup = true;

    meta = {
      description = "DeepSeek Harness — plugin-based agent harness (everything is a plugin)";
      homepage = "https://github.com/deepseek-ai/deepseek-harness";
      license = lib.licenses.mit;
      mainProgram = "dsh";
    };
  };
in
{
  imports = [
    ./skills.nix
  ];

  home.packages = [
    dsh
    # dsh 运行时依赖(必须):
    pkgs.nodejs_22 # dsh 子进程/spawn helper 需要 node 在 PATH
    pkgs.ripgrep   # dsh-tool-fs-search 通过 ctx.subprocess 调用 rg
    pkgs.bubblewrap # dsh sandbox-local 的 Linux 沙箱后端(workspace-write/read-only 模式需要;
                    # 探测方式:spawnSync('bwrap', ...);缺它则报 "no sandbox backend usable")
    # 说明:bash 工具走系统 /bin/bash,无需额外安装

    # 便捷启动:启动 dsh web 并自动打开默认浏览器(xdg-open),然后立即退出。
    # dsh web 作为后台服务继续运行(nohup),日志在 ~/.dsh-web.log。
    # 用法:dsh-web [port]  (dsh 本身不自动打开浏览器,只打印 URL)
    (pkgs.writeShellScriptBin "dsh-web" ''
      PORT="''${1:-3080}"
      URL="http://127.0.0.1:$PORT/"

      # 端口无实例时:后台启动 dsh web 并脱离终端,等端口就绪
      if ! curl -sf -o /dev/null "$URL" 2>/dev/null; then
        nohup dsh web --port "$PORT" > "$HOME/.dsh-web.log" 2>&1 &
        disown
        for _ in $(seq 1 30); do
          curl -sf -o /dev/null "$URL" 2>/dev/null && break
          sleep 1
        done
      fi

      # 确认服务可用后再打开浏览器
      if ! curl -sf -o /dev/null "$URL" 2>/dev/null; then
        echo "dsh web 未能启动,请查看日志: ~/.dsh-web.log" >&2
        exit 1
      fi
      echo "$URL"
      xdg-open "$URL"
    '')
  ];

  # ─────────────────────────────────────────────────────────────────────────────
  # context / skills 配置入口(默认全部注释 = 零配置)
  #
  # dsh 的用户数据根目录为 ~/.dsh(可用环境变量 DSH_HOME 覆盖),所有用户
  # 配置都是"放文件即生效",启动时自动发现,无需改 dsh 本身。
  # ─────────────────────────────────────────────────────────────────────────────
  home.file = {
    ".dsh/AGENTS.md".source = ../agent-context.md;

    # ─────────────────────────────────────────────────────────────────────────
    # 权限策略插件 confirm-writes(与 pi 相同:读放行,写/执行询问)
    # ─────────────────────────────────────────────────────────────────────────
    # 插件本体(零依赖 ESM,loader 经相对路径加载)
    ".dsh/profiles/web/plugins/confirm-writes.mjs".source = ./profiles/web/plugins/confirm-writes.mjs;

    # web profile 的用户 patch 层:挂载 confirm-writes 插件。
    # 注意:此文件由 home-manager 声明式管理;如需追加自己的 patch 行,
    # 请直接编辑 dsh.nix 中此处的内容(改后 home-manager switch 生效)。
    ".dsh/profiles/web/cordis.patch.yml".source = ./profiles/web/cordis.patch.yml;
  };
}
