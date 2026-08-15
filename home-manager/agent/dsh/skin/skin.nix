{ lib, pkgs, ... }:

let
  # ── dsh-deep-whale 鲸鱼娘皮肤系列 ──────────────────────────────────────
  # https://github.com/Small-tailqwq/dsh-deep-whale:DSH Web 鲸鱼娘皮肤。
  # 本模块安装其中的 maid-atelier(深海女仆工坊,CC BY-NC-SA 4.0),
  # 是官方 `dsh plugin --profile web add <path>` 的声明式等价物。
  # 固定 rev;hash 由 nix-prefetch-url --unpack 计算。
  dshDeepWhaleSrc = pkgs.fetchFromGitHub {
    owner = "Small-tailqwq";
    repo = "dsh-deep-whale";
    rev = "cdb4da4f9c708571c6303cc1053185c62c8b617b";
    hash = "sha256-/b/BfwOC17AW3BV6edgO7CRx2JBk/W2qJKmNyEekDwY=";
  };

  # 在 pinned 源码上叠加可读性修复:
  # - maid-atelier-tool-blur.patch:工具调用/命令/thinking/上下文注入的
  #   disclosure 表面本来是低不透明度的瓷白/深蓝渐变,直接压在皮肤自身的
  #   深蓝宫殿背景上,蓝字读蓝底非常费眼。patch 给展开容器和折叠行分别
  #   加 backdrop-filter(12px/8px blur + 轻微 desaturate),只模糊取样到的
  #   背景、不改变卡片本身的透明度。bash 工具视图不走共享 DisclosureRow
  #   (data-variant='bash' 本身就是单行折叠条),单独给这条透明行补 8px blur。
  # - backport-maid-atelier-blur.py:仓库没有锁文件,home-manager 不重建
  #   皮肤 bundle;浏览器真正加载的是 lib/client.js 里内联的压缩 CSS,
  #   脚本把与源码 patch 等价的 override 追加到该 CSS 串尾部(原规则在
  #   前、追加规则在后,同优先级时追加规则胜出)。
  # 产物仍是完整皮肤包;web profile 的 cordis.patch.yml 以包名
  # '@dsh-external/dsh-client-ui-skin-maid-atelier' 把它挂进插件树
  # (insert 行在 profiles/web/cordis.patch.yml,与其他 web 插件共处一层)。
  dshDeepWhalePatched = pkgs.stdenv.mkDerivation {
    pname = "dsh-deep-whale";
    version = "cdb4da4f9c708571c6303cc1053185c62c8b617b";
    src = dshDeepWhaleSrc;

    patches = [
      ./maid-atelier-tool-blur.patch
    ];

    nativeBuildInputs = [ pkgs.python3 ];

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -r . "$out/"
      # store 源文件为只读,后处理需要写 lib/client.js
      chmod -R u+w "$out"
      python3 ${./backport-maid-atelier-blur.py} \
        "$out/maid-atelier/lib/client.js"
      runHook postInstall
    '';

    dontFixup = true;
  };
in
{
  # ─────────────────────────────────────────────────────────────────────────
  # maid-atelier 皮肤包的真实文件部署
  #
  # home.file 的产物一律是符号链接;Node ESM 加载插件时会 realpath 到
  # /nix/store,包内的相对导入/资源引用就会逃逸。因此沿用 dshPlugins
  # 的做法,在 linkGeneration 之后把打过补丁的皮肤包真实拷贝到
  # ~/.dsh/profiles/web/node_modules/@dsh-external/ 下,与官方
  # `dsh plugin add` 的落点一致,但不写入 package.json、不依赖 pnpm。
  # 卸载配置模块后这些真实文件不会被 linkGeneration 清理,属预期行为。
  # ─────────────────────────────────────────────────────────────────────────
  home.activation.dshSkinMaidAtelier = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run mkdir -p \
      "$HOME/.dsh/profiles/web/node_modules/@dsh-external"

    # 整目录真实文件部署:先清掉旧版本再重拷,保证升级时已删除的旧文件不
    # 残留。remove-without-permission 是系统预装的 rm 包装(参数与 rm
    # 完全一致),仓库规则不允许脚本直接 rm。激活脚本 PATH 不含系统
    # profile,故用 /run/current-system/sw/bin 绝对路径;store 源经 cp -r
    # 部署后是只读文件/目录,先 chmod 恢复写权限。
    if [ -e "$HOME/.dsh/profiles/web/node_modules/@dsh-external/dsh-client-ui-skin-maid-atelier" ]; then
      run chmod -R u+w \
        "$HOME/.dsh/profiles/web/node_modules/@dsh-external/dsh-client-ui-skin-maid-atelier"
    fi
    run /run/current-system/sw/bin/remove-without-permission -rf \
      "$HOME/.dsh/profiles/web/node_modules/@dsh-external/dsh-client-ui-skin-maid-atelier"
    run cp -r ${dshDeepWhalePatched}/maid-atelier \
      "$HOME/.dsh/profiles/web/node_modules/@dsh-external/dsh-client-ui-skin-maid-atelier"
  '';
}
