# hermes-agent — Nous Research 的自改进型 AI agent（Python 包）
#
# nixpkgs 不提供此包，故从源码构建。rev/sha256 固定（见 AGENTS.md 可复现性规则）。
#
# 构建要点（对照上游官方 nix/hermes-agent.nix）：
# - requires-python = ">=3.11,<3.14"，用 python312
# - setup.py 的 wheel 构建守卫要求 HERMES_NIX_BUILD=1 才放行（官方 Nix 构建同样如此）
# - pyproject.toml 核心依赖映射到 nixpkgs 的 python312Packages（版本以 nixpkgs 为准；
#   上游精确 pin 是为了供应链安全而非 API 兼容性）
# - 排除的依赖：
#   * nemo-relay —— 上游仅发布 wheel（无 sdist）且 nixpkgs 没有；hermes 对其是
#     惰性导入并带 NoopRelayRuntime 回退（agent/relay_runtime.py），省略不影响运行
#   * tzdata / pywinpty / pywin32 / concurrent-log-handler —— 仅 Windows 平台 marker
# - openai/fastapi 关闭 check：nixpkgs-unstable 的 scipy 1.18.0 测试套件在
#   numpy 2.5.1 下失败（hypothesis 反例 test_support_moments_sample），而 scipy
#   只出现在它们 checkInputs 的测试闭包里（openai/fastapi → inline-snapshot →
#   isort → pylama → vulture → pint → uncertainties → scipy），运行时用不到
# - 可选依赖（hermes doctor 提示缺失、nixpkgs 已提供，一并加入）：
#   * python-telegram-bot / discordpy —— messaging（网关收发消息）
#   * lark-oapi —— feishu_doc / feishu_drive 工具（飞书文档/云盘）
#   * edge-tts —— tts 工具默认 provider（edge）需要
# - cua-driver（computer_use 工具）：上游发布预编译二进制（trycua/cua
#   release），用 fetchurl 固定版本 + hash 打包；动态链接 libX11/libXi/
#   xkbcommon，用 makeWrapper 提供 LD_LIBRARY_PATH，并经
#   HERMES_CUA_DRIVER_CMD 指给 hermes
# - 运行时资源（skills/optional-skills/plugins/locales/optional-mcps）复制进
#   $out/share/hermes-agent，并由 wrapper 用 env 变量指向（官方同款做法）：
#   * HERMES_BUNDLED_LOCALES：不设的话界面会显示原始 i18n key 而非中文/英文文案
#   * HERMES_BUNDLED_PLUGINS：memory / context_engine / platforms 等插件
#   * HERMES_BUNDLED_SKILLS：内置技能，首次运行时 sync_skills 会同步进
#     ~/.hermes/skills/；与 pi 迁移的同名技能不会互相覆盖（sync 跳过用户已有技能）
# - Node TUI（ui-tui，npm 项目）与 Electron 桌面端不构建：`hermes` 默认的
#   rich REPL 交互不受影响，仅 `hermes --tui` 不可用
{ pkgs, lib, ... }:

let
  python = (pkgs.python312.override {
    packageOverrides = self: super: {
      openai = super.openai.overridePythonAttrs (_: { doCheck = false; });
      fastapi = super.fastapi.overridePythonAttrs (_: { doCheck = false; });
      # lark-oapi 自带测试含 flaky 异步用例（test_stop_during_pre_ws_start_*
      # 偶发失败），跳过；仅作 feishu 工具运行时库
      lark-oapi = super.lark-oapi.overridePythonAttrs (_: { doCheck = false; });
    };
  });

  rev = "427584b76841c09f419ffc95c7651d995c57d4ed";

  hermesSrc = pkgs.fetchFromGitHub {
    owner = "NousResearch";
    repo = "hermes-agent";
    inherit rev;
    sha256 = "1nxiq6yha9av9hxsq0f8j0ny5lpim4wfwh60lj5b9la4k6z79yw6";
  };

  # 清理 __pycache__ / index-cache（官方用 lib.cleanSourceWith 过滤，这里拷贝后清理）
  cleanDir = dir: ''
    rm -rf ${dir}/__pycache__ 2>/dev/null || true
    find ${dir} -type d -name __pycache__ -prune -exec rm -rf {} + 2>/dev/null || true
    rm -rf ${dir}/index-cache 2>/dev/null || true
  '';

  # Hermes Desktop（Electron）renderer：npm 构建产物（见 desktop.nix）
  desktop = import ./desktop.nix {
    inherit pkgs lib hermesSrc;
    version = "0.20.0";
  };

  # cua-driver —— hermes computer_use 工具的后端（MCP 服务二进制）
  # 上游仅发布预编译 release（trycua/cua），nixpkgs 无此包，固定版本 + hash
  cuaDriver = pkgs.stdenv.mkDerivation {
    pname = "cua-driver";
    version = "0.19.1";

    src = pkgs.fetchurl {
      url = "https://github.com/trycua/cua/releases/download/cua-driver-rs-v0.19.1/cua-driver-rs-0.19.1-linux-x86_64-binary.tar.gz";
      sha256 = "1sxic1xqsnrap09p3jk5c44hcwv99zb8f318zkcc29yahxw6wngn";
    };

    dontConfigure = true;
    dontBuild = true;
    dontUnpack = true;  # tarball 含多个顶层文件，手动解压避免 stdenv 自动 cd 进子目录
    nativeBuildInputs = [ pkgs.makeWrapper ];

    installPhase = ''
      runHook preInstall
      tar xzf $src -C $TMPDIR
      mkdir -p $out/libexec/cua-driver $out/bin
      cp -r $TMPDIR/* $out/libexec/cua-driver/
      chmod +x $out/libexec/cua-driver/cua-driver
      # 动态链接 libX11/libXi/libxkbcommon（NixOS 下不在标准路径）
      makeWrapper $out/libexec/cua-driver/cua-driver $out/bin/cua-driver \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ pkgs.libX11 pkgs.libXi pkgs.libxkbcommon ]}"
      runHook postInstall
    '';

    meta = with lib; {
      description = "cua-driver — computer-use agent driver (trycua/cua)";
      homepage = "https://github.com/trycua/cua";
      license = licenses.asl20;
      platforms = [ "x86_64-linux" ];
    };
  };
in
python.pkgs.buildPythonApplication {
  pname = "hermes-agent";
  version = "0.20.0";

  src = hermesSrc;

  pyproject = true;
  build-system = with python.pkgs; [ setuptools wheel ];

  # setup.py 的 bdist_wheel/sdist 守卫：仅 Nix 构建（HERMES_NIX_BUILD=1）放行
  env.HERMES_NIX_BUILD = "1";

  dependencies = with python.pkgs; [
    # 核心运行时
    openai
    certifi
    python-dotenv
    fire
    httpx
    rich
    tenacity
    pyyaml
    ruamel-yaml
    requests
    jinja2
    pydantic
    prompt-toolkit
    croniter
    packaging
    markdown
    pyjwt
    urllib3
    cryptography
    psutil
    websockets
    pathspec
    tzdata
    # 仪表盘 / web profile（fastapi + uvicorn[standard] 近似：uvloop/httptools）
    fastapi
    uvicorn
    uvloop
    httptools
    python-multipart
    # 平台相关
    ptyprocess
    pillow
    # httpx[socks] 与 PyJWT[crypto] 的额外依赖
    socksio
    # 可选依赖：messaging（网关）/ feishu 工具 / tts 默认 provider
    python-telegram-bot
    discordpy
    lark-oapi
    edge-tts
  ];

  # 上游精确 pin（==X.Y.Z）与 nixpkgs 版本不一致，跳过 wheel 元数据的运行时
  # 依赖版本检查（pythonRuntimeDepsCheckHook）；版本差异仅是补丁级，不影响 API
  dontCheckRuntimeDeps = true;

  doCheck = false;

  postInstall = ''
    mkdir -p $out/share/hermes-agent
    cp -r ${hermesSrc}/skills          $out/share/hermes-agent/skills
    cp -r ${hermesSrc}/optional-skills $out/share/hermes-agent/optional-skills
    cp -r ${hermesSrc}/plugins         $out/share/hermes-agent/plugins
    cp -r ${hermesSrc}/locales         $out/share/hermes-agent/locales
    cp -r ${hermesSrc}/optional-mcps   $out/share/hermes-agent/optional-mcps
    ${cleanDir "$out/share/hermes-agent/skills"}
    ${cleanDir "$out/share/hermes-agent/optional-skills"}
    ${cleanDir "$out/share/hermes-agent/plugins"}

    # ---- Hermes Desktop 集成：让 `hermes desktop` 能直接启动 ----
    # cmd_gui（hermes desktop）要求 PROJECT_ROOT（=$out/lib/python3.12/site-packages）下有
    # apps/desktop/package.json 和 apps/desktop/release/linux-unpacked/hermes
    # （packaged executable），且 build stamp（~/.hermes/desktop-build-stamp.json）
    # 与源码 contentHash 匹配时跳过 npm 构建、直接启动。
    desktopDir="$out/lib/python3.12/site-packages/apps/desktop"
    mkdir -p "$desktopDir/release/linux-unpacked"
    cp -r ${desktop}/dist "$desktopDir/dist"
    cp ${desktop}/package.json "$desktopDir/package.json"
    cp ${desktop}/install-stamp.json "$desktopDir/install-stamp.json"
    # 根 workspace 文件：contentHash 计算（_compute_desktop_content_hash）需要
    cp ${hermesSrc}/package.json ${hermesSrc}/package-lock.json ${hermesSrc}/.gitignore "$out/lib/python3.12/site-packages/"

    # 启动脚本：nixpkgs electron 加载 renderer（package.json main → dist/electron-main.mjs）
    cat > "$desktopDir/release/linux-unpacked/hermes" <<LAUNCHER
#!/usr/bin/env bash
# Hermes Desktop 启动脚本（nix 构建）—— cmd_gui 会直接 spawn 此文件
export HERMES_DESKTOP_HERMES="$out/bin/hermes"
exec "${desktop.electron}/bin/electron" "$desktopDir" "\$@"
LAUNCHER
    chmod +x "$desktopDir/release/linux-unpacked/hermes"

    # nix 下 electron 的 process.resourcesPath 指向 electron 发行目录，
    # 改为应用目录（官方 nix/desktop.nix 同款做法，保证 extraResources 可读）
    substituteInPlace "$desktopDir/dist/electron-main.mjs" \
      --replace-fail "process.resourcesPath" "'$desktopDir'"

    # ---- 自定义 hermes wrapper：`hermes desktop` 直接启动 GUI ----
    # cmd_gui 启动前检查 Electron 的 setuid chrome-sandbox（要求 uid==0 且 4755），
    # nix store 无法创建 setuid 文件（nix 沙盒禁止 chmod +s）→ fixup 失败 →
    # cmd_gui 直接 sys.exit(1)。因此把 desktop 子命令路由到启动脚本，
    # 绕过该检查（electron 用自己的 sandbox，安全性不变）。
    real="$out/bin/.hermes-real"
    mv "$out/bin/hermes" "$real"
    # 路径替换（@占位符@；store 路径不含 @）
    sed \
      -e "s|@HERMES@|$out/bin/hermes|g" \
      -e "s|@REAL@|$real|g" \
      -e "s|@ELECTRON@|${desktop.electron}/bin/electron|g" \
      -e "s|@APPDIR@|$out/lib/python3.12/site-packages/apps/desktop|g" \
      ${./desktop-launcher.sh} > "$out/bin/hermes"
    chmod +x "$out/bin/hermes"

    # 桌面图标（.desktop 的 Icon=hermes，freedesktop hicolor 规范）
    mkdir -p $out/share/icons/hicolor/1024x1024/apps
    cp ${hermesSrc}/apps/desktop/assets/icon.png $out/share/icons/hicolor/1024x1024/apps/hermes.png

    # 计算 desktop 源码 contentHash 并写 stamp（hermes desktop 据此跳过 npm 构建；
    # hermes.nix 的 activation 会把 stamp 复制到 ~/.hermes/）
    cat > "$TMPDIR/desktop-stamp.py" <<'PYEOF'
import hashlib, json, os
from pathlib import Path
from pathspec import PathSpec
project_root = Path(os.environ["DESKTOP_PROJECT_ROOT"])
h = hashlib.sha256()
def _hash_file(path):
    rel = str(path.relative_to(project_root))
    h.update(rel.encode()); h.update(b"\0")
    try:
        with open(path, "rb") as f:
            for chunk in iter(lambda: f.read(65536), b""):
                h.update(chunk)
    except (OSError, IOError):
        pass
    h.update(b"\0")
gitignore = project_root / ".gitignore"
lines = gitignore.read_text(encoding="utf-8").splitlines() if gitignore.is_file() else []
spec = PathSpec.from_lines("gitignore", lines)
for name in ("package.json", "package-lock.json"):
    p = project_root / name
    if p.is_file() and not spec.match_file(str(p.relative_to(project_root))):
        _hash_file(p)
desktop_dir = project_root / "apps" / "desktop"
for dirpath, dirnames, filenames in os.walk(desktop_dir, topdown=True):
    dirnames[:] = [d for d in dirnames if not spec.match_file(str((Path(dirpath) / d).relative_to(project_root)))]
    for fn in sorted(filenames):
        fp = Path(dirpath) / fn
        rel = str(fp.relative_to(project_root))
        if not spec.match_file(rel):
            _hash_file(fp)
stamp = {"contentHash": h.hexdigest(), "sourceMode": False}
Path(os.environ["DESKTOP_STAMP_OUT"]).write_text(json.dumps(stamp) + "\n", encoding="utf-8")
print("desktop contentHash:", h.hexdigest())
PYEOF
    DESKTOP_PROJECT_ROOT="$out/lib/python3.12/site-packages" \
      DESKTOP_STAMP_OUT="$out/share/hermes-agent/desktop-build-stamp.json" \
      ${python}/bin/python3 "$TMPDIR/desktop-stamp.py"
  '';

  makeWrapperArgs = [
    # 运行时资源（与官方 nix/hermes-agent.nix 的 wrapper 一致）
    "--set HERMES_BUNDLED_SKILLS $out/share/hermes-agent/skills"
    "--set HERMES_OPTIONAL_SKILLS $out/share/hermes-agent/optional-skills"
    "--set HERMES_BUNDLED_PLUGINS $out/share/hermes-agent/plugins"
    "--set HERMES_BUNDLED_LOCALES $out/share/hermes-agent/locales"
    "--set HERMES_OPTIONAL_MCPS $out/share/hermes-agent/optional-mcps"
    # 版本/构建信息（替代 git checkout 的 rev 探测）
    "--set HERMES_REVISION ${rev}"
    "--set HERMES_PYTHON ${python}/bin/python3"
    # computer_use 后端（cua-driver 预编译二进制）
    "--set HERMES_CUA_DRIVER_CMD ${cuaDriver}/bin/cua-driver"
    # 工具链（rg/ffmpeg/node 等；系统已有 rg/ffmpeg/node，这里兜底保证可用）
    "--suffix PATH : ${lib.makeBinPath (with pkgs; [ nodejs ripgrep git openssh ffmpeg tirith wl-clipboard ])}"
  ];

  meta = with lib; {
    description = "The self-improving AI agent by Nous Research";
    homepage = "https://github.com/NousResearch/hermes-agent";
    license = licenses.mit;
    mainProgram = "hermes";
    platforms = platforms.linux;
  };
}
