# Hermes Desktop（Electron）renderer 构建
#
# 对照上游官方 nix/desktop.nix：用 nixpkgs buildNpmPackage 构建 renderer
# （tsc 类型检查 + vite 打包 + electron-main bundle），node-pty 针对 nixpkgs
# electron 的 ABI 从源码编译（headers 固定 fetchurl，沙盒内无网络）。
# 产物是 apps/desktop/dist 结构 + install-stamp.json + package.json。
# 运行时用 nixpkgs electron 加载（见 package.nix 中的桌面集成）。
#
# 注意：npm ci（npmDeps 阶段）需要网络，会从 npm registry 下载全部
# workspace 依赖（一次性，FOD 缓存）。
{ pkgs, lib, hermesSrc, version }:

let
  electron = pkgs.electron;  # nixpkgs electron（node-pty 按其 ABI 编译）

  # node-pty 编译需要 electron 头文件（node-gyp --nodedir）
  electronHeaders = pkgs.fetchurl {
    url = "https://artifacts.electronjs.org/headers/dist/v${electron.version}/node-v${electron.version}-headers.tar.gz";
    sha256 = "15crrr4x8hmqlkf6cgvikl6xdhgsdi0bqh12vkyv7db6nind5ikz";
  };

  # 构建源：workspace manifests + apps/desktop + apps/shared + .gitignore
  # （npm ci 需要全部 workspace 成员的 package.json 解析 workspace: 依赖）
  src = pkgs.runCommand "hermes-desktop-src" { } ''
    mkdir -p $out/apps $out/ui-tui/packages/hermes-ink $out/web $out/tests-js
    cp -r ${hermesSrc}/apps/desktop $out/apps/desktop
    cp -r ${hermesSrc}/apps/shared $out/apps/shared
    cp ${hermesSrc}/package.json ${hermesSrc}/package-lock.json ${hermesSrc}/.gitignore $out/
    cp ${hermesSrc}/ui-tui/package.json $out/ui-tui/package.json
    cp ${hermesSrc}/ui-tui/packages/hermes-ink/package.json $out/ui-tui/packages/hermes-ink/package.json
    cp ${hermesSrc}/web/package.json $out/web/package.json
    cp ${hermesSrc}/tests-js/package.json $out/tests-js/package.json
  '';
in
pkgs.buildNpmPackage {
  pname = "hermes-desktop-renderer";
  inherit version src;

  # nix hash of npm deps（workspace 全部依赖，FOD）
  npmDepsHash = "sha256-33ALD6Th++LCp8JiVO6ba27GhuP3GBuLGUuyoJg99iM=";

  # npm ci 后 npmConfigHook 会跑 `npm rebuild`（重跑全部 postinstall，
  # electron 的 install.js 会尝试下载二进制 → 沙盒无网络失败）。
  # 跳过；node-pty 在 buildPhase 里针对 electron ABI 手动编译。
  npmRebuildFlags = [ "--ignore-scripts" ];

  # node-gyp（node-pty 编译）+ python（node-gyp 需要）
  nativeBuildInputs = [ pkgs.node-gyp pkgs.python3 ];

  buildPhase = ''
    runHook preBuild

    mkdir -p apps/desktop/build
    patchShebangs .

    pushd apps/desktop
      # typecheck（编译 apps/desktop + apps/shared 的 TS）
      npm exec -- tsc -b

      # renderer bundle（vite 先跑，会清空 dist/）
      npm exec -- vite build

      # electron 主进程 bundle
      node scripts/bundle-electron-main.mjs

      # node-pty：针对 electron ABI 从源码编译（headers 来自固定 fetchurl，
      # 沙盒内 node-gyp 的 --disturl 下载路径不可用）
      mkdir -p "$TMPDIR/electron-headers"
      tar -xzf ${electronHeaders} -C "$TMPDIR/electron-headers" --strip-components=1

      node-gyp rebuild \
        --directory=../../node_modules/node-pty \
        --build-from-source \
        --runtime=electron \
        --target=${electron.version} \
        --nodedir="$TMPDIR/electron-headers" \
        --disturl="" \
        --offline

      # 把 node-pty 原生产物 stage 进 dist/
      node scripts/stage-native-deps.mjs linux x64
    popd

    runHook postBuild
  '';

  checkPhase = ''
    runHook preCheck
    pushd apps/desktop
      # 校验 node-pty 原生二进制已 stage
      if [ ! -f "./dist/node_modules/node-pty/build/Release/pty.node" ]; then
        echo "FATAL: Missing staged node-pty native binary at dist/node_modules/node-pty/build/Release/pty.node"
        exit 1
      fi
    popd
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -rn apps/desktop/dist $out/
    # 版本 stamp（desktop 启动时 bootstrap 读取；nix 构建无 git）
    echo '{"schemaVersion":1,"commit":"nix-dummy-commit","branch":"nix","dirty":false,"source":"nix"}' > $out/install-stamp.json
    cp -n apps/desktop/package.json $out/
    runHook postInstall
  '';

  passthru = { inherit electron; };

  meta = with lib; {
    description = "Hermes Desktop renderer (Electron app bundle)";
    homepage = "https://github.com/NousResearch/hermes-agent";
    license = licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
