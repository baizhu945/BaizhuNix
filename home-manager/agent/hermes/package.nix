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
