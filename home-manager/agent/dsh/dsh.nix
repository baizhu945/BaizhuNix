{ config, pkgs, lib, ... }:

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

    patches = [
      ./patches/expand-running.patch
      ./patches/tool-bottom-collapse.patch
      ./patches/bash-command-hscroll.patch
      ./patches/durable-session-lease.patch
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

  # agent preset:dsh-anchored-standard(xiaobright,社区实验性 preset)
  # Anchored Standard:首次请求用 Minimal 对齐的双工具目录(不注入工作区/技能
  # 上下文),会话出现首次持久晋升信号(tool/call 或 assistant/message)后开放
  # 完整 Standard 工具目录。固定 rev 而非分支;hash 由 nix-prefetch-url --unpack 计算。
  dshPresetSrc = pkgs.fetchFromGitHub {
    owner = "xiaobright";
    repo = "dsh-anchored-standard";
    rev = "6472c1c9431dcfd9072be23bff781b76fe7146c0";
    hash = "sha256-R+QCRXtB16fObeVTpz6aXPabGAkWtl/mR+hvW7dNmAw=";
  };

  # 在 pinned preset 上叠加 vision 兜底 subagent(anchored-standard-vision.patch):
  # - 新增 `vision` 工具:spawn 一个 MiniMax M3 子代理(前台一次性),
  #   toolFilter 只保留 read_image/read/glob/grep,maxDepth 1 禁止继续委派;
  # - persona 中加入路由指引:主模型无图像输入时把图片路径交给 vision;
  # - bootstrap 首请求工具目录加入 vision,首个问题带图也能走兜底。
  # fetchFromGitHub 产物只读,这里复制出可写目录后打补丁,再交给 home.file。
  dshAnchoredPreset = pkgs.runCommand "dsh-anchored-standard-preset" {
    presetSrc = "${dshPresetSrc}/preset";
    visionPatch = ./patches/anchored-standard-vision.patch;
  } ''
    mkdir -p "$out"
    cp -r "$presetSrc/." "$out/"
    chmod -R u+w "$out"
    cd "$out"
    ${pkgs.gnupatch}/bin/patch -p2 < "$visionPatch"
  '';
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

    # 便捷启动(生命周期与浏览器窗口绑定,脚本主体见 ./dsh-web.sh):
    # 1. 端口空闲时启动 dsh web(端口已有实例则直接复用);
    # 2. 打开一个独立 chromium 应用窗口(临时 profile,可被脚本监控);
    # 3. 脚本挂起,直到关闭该窗口或按 Ctrl+C;
    # 4. 退出时杀掉本次运行启动的 webui 进程并清理临时 profile
    #    (复用的已有实例不会被杀)。
    # 用法:dsh-web [port]  (默认 3080;浏览器可用 DSH_BROWSER 覆盖)
    (pkgs.writeShellScriptBin "dsh-web" (builtins.readFile ./dsh-web.sh))
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

    # web profile 的用户 patch 层:挂载 confirm-writes + approval-tweaks 插件。
    # 注意:此文件由 home-manager 声明式管理;如需追加自己的 patch 行,
    # 请直接编辑 dsh.nix 中此处的内容(改后 home-manager switch 生效)。
    ".dsh/profiles/web/cordis.patch.yml".source = ./profiles/web/cordis.patch.yml;

    # ─────────────────────────────────────────────────────────────────────
    # 审批面板插件 dsh-baizhu-approval(approval-always-allow +
    # approval-keyboard 两个源码补丁的插件迁移,双半包):
    # - host 半体 index.mjs:空 apply,让本行出现在 host 组合中;
    # - client 半体 client.js:浏览器 bundle,composer chain 接管审批 UI。
    # 安装到 web profile 自己的 node_modules(createRequire(baseUrl) 从此
    # 解析包名)。真实文件由下方 home.activation.dshPlugins 部署:
    # home.file 的产物一律是符号链接,Node ESM 会把符号链接 realpath 到
    # /nix/store,将来插件内一旦出现 bare import 就找不到 profile 的
    # node_modules(与 headless 插件同因)。
    # 注意:`dsh plugin` 用 pnpm 管理该目录时可能清掉它,
    # 重新 home-manager switch 即可恢复。
    # ─────────────────────────────────────────────────────────────────────

    # ─────────────────────────────────────────────────────────────────────
    # headless profile 插件(cc-connect 集成;headless-cc-connect.patch 的
    # 插件迁移):headless patch 层禁用内置 startup/runner,挂两个本地插件。
    # 插件 .mjs 的 bare import(@deepseek-ai/dsh-*)由 dsh 每次启动时维护的
    # ~/.dsh/profiles/node_modules 扁平链接解析(healProfilesModuleFallback,
    # 指向 apps/cli 自己的依赖树,保证与内置插件共享同一份 cordis 等实例)。
    # 插件文件因此必须部署为 ~/.dsh 下的真实文件(不能是符号链接:
    # realpath 会逃逸到 /nix/store,Node 就找不到模块),由下方
    # home.activation.dshPlugins 完成。
    # force = true:dsh 首次创建 profile 时会生成一个 `[]` 模板
    # cordis.patch.yml,由 home-manager 接管覆盖(该文件本就是用户层,
    # dsh 之后不再写入)。
    # ─────────────────────────────────────────────────────────────────────
    ".dsh/profiles/headless/cordis.patch.yml" = {
      source = ./profiles/headless/cordis.patch.yml;
      force = true;
    };

    # ─────────────────────────────────────────────────────────────────────
    # home-level patch(~/.dsh/cordis.patch.yml,web/headless 所有 profile
    # 生效):llm-retry-default-5.patch 的声明式配置迁移。retry policy 是
    # provider 插件的配置字段,为 deepseek-official(llm-deepseek)与
    # minimax-cn(llm-pi-ai)显式设置 maxRetries: 5。settings.yaml 用户层
    # 会逐键深合并到此处 base 上,不会互相覆盖。
    # ─────────────────────────────────────────────────────────────────────
    ".dsh/cordis.patch.yml".source = ./home-cordis.patch.yml;

    # ─────────────────────────────────────────────────────────────────────
    # agent preset:dsh-anchored-standard(Anchored Standard,实验性)
    # 安装到 ~/.dsh/.agent-presets/anchored-standard/(目录 id = preset id),
    # web 新会话的 preset 选择器中可见(选择 "Anchored Standard (experimental)")。
    # recursive = true:dsh 发现逻辑用 Dirent.isDirectory() 判断 preset 目录,
    # 不跟随符号链接,故不能用默认的"整目录符号链接",而需真实目录 + 叶子文件
    # 符号链接(叶子符号链接 readFile 会正常跟随,loader 相对导入 ./xxx.mjs 也 OK)。
    # 源为 dshAnchoredPreset(pinned preset + vision subagent 补丁后的副本),
    # 文件只读、可复现、跟随升级。
    # ─────────────────────────────────────────────────────────────────────
    ".dsh/.agent-presets/anchored-standard" = {
      source = "${dshAnchoredPreset}";
      recursive = true;
    };
  };

  # ─────────────────────────────────────────────────────────────────────────
  # 插件文件的真实文件部署
  #
  # home.file 的所有产物(含 .text)都是符号链接;Node ESM 加载插件时会
  # realpath 到 /nix/store,插件内部的 bare import(@deepseek-ai/dsh-* 等)
  # 就找不到 ~/.dsh/profiles/node_modules(dsh 每次启动 heal 的扁平链接,
  # 指向 apps/cli 自己的依赖树 —— 必须从这条路径导入,才能与内置插件共享
  # 同一份 cordis 模块实例)。因此这两个插件目录用激活脚本把 store 里的
  # 文件真实拷贝到 ~/.dsh(linkGeneration 之后运行,install 会原子替换
  # 旧的符号链接)。卸载时这些真实文件不会被 linkGeneration 清理,
  # 属预期行为(删除配置模块后手动清理即可)。
  # ─────────────────────────────────────────────────────────────────────────
  home.activation.dshPlugins = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run mkdir -p \
      "$HOME/.dsh/profiles/headless/plugins" \
      "$HOME/.dsh/profiles/web/node_modules/dsh-baizhu-approval"
    run install -m 644 ${./profiles/headless/plugins/cc-connect-startup.mjs} \
      "$HOME/.dsh/profiles/headless/plugins/cc-connect-startup.mjs"
    run install -m 644 ${./profiles/headless/plugins/cc-connect-runner.mjs} \
      "$HOME/.dsh/profiles/headless/plugins/cc-connect-runner.mjs"
    run install -m 644 ${./profiles/web/node_modules/dsh-baizhu-approval/package.json} \
      "$HOME/.dsh/profiles/web/node_modules/dsh-baizhu-approval/package.json"
    run install -m 644 ${./profiles/web/node_modules/dsh-baizhu-approval/index.mjs} \
      "$HOME/.dsh/profiles/web/node_modules/dsh-baizhu-approval/index.mjs"
    run install -m 644 ${./profiles/web/node_modules/dsh-baizhu-approval/client.js} \
      "$HOME/.dsh/profiles/web/node_modules/dsh-baizhu-approval/client.js"
  '';
}
