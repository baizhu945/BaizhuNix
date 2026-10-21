{ lib, pkgs, config, ... }:

let
  # cursor-cli 自带的 node 被 autoPatchelfHook 添加 RUNPATH 时，patchelf 会重写
  # 文件并生成两个重叠的 PT_LOAD：新加的可写段与原来的只读段映射同一批虚拟地址，
  # 内核按 program header 顺序映射，后者的只读映射覆盖了 .dynamic 所在页。
  # glibc 的 ld.so 启动时会往可执行文件的 DT_DEBUG 里写 r_debug 指针，
  # 于是写只读页 -> SIGSEGV（连 `node --version` 都跑不起来）。
  # 在 autoPatchelf 之后修正段权限，详见 fix-load-segments.py。
  cursorCli = pkgs.cursor-cli.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.python3 ];

    preFixup = (old.preFixup or "") + ''
      fixCursorNodeElf() {
        local node="$out/share/cursor-agent/node"
        [ -e "$node" ] || return 0
        chmod u+w "$node"
        python3 ${./fix-load-segments.py} "$node"
      }
      # preFixup 是 fixupPhase 的第一步，此时 autoPatchelfHook 已经把
      # autoPatchelfPostFixup 注册进 postFixupHooks；这里再追加，保证我们的
      # 修正排在 patchelf 重写之后执行。
      postFixupHooks+=(fixCursorNodeElf)
    '';
  });
in
{
  programs.cursor = {
    enable = true;
    package = cursorCli;
  };

  home.file = {
    ".cursor/rules/AGENTS.md".source = ../agent-context.md;
  };
}
