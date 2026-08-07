# hermes-agent 声明式安装 + pi context/skills 迁移
#
# 说明：
# - hermes 会自行修改 context（SOUL.md）与 skills（skill 管理/curator 等），
#   因此不能像 pi 那样用 home.file 符号链接（nix store 只读，hermes 无法写入），
#   而是用 activationScript 做真实拷贝；目标已存在则不复制（不比对内容），
#   保证 hermes 对文件的后续修改不会被 home-manager 覆盖。
# - context：pi 的 agent-context.md → hermes 全局 context ~/.hermes/SOUL.md
#   （SOUL.md 是 hermes 唯一从 HERMES_HOME 加载的全局 context 文件，每次会话注入）
# - skills：pi 的 ~/.pi/agent/skills/（含 nix store 符号链接，cp -rL 解引用为
#   真实目录）+ superpowers（~/.pi/agent/git/github.com/obra/superpowers/skills）
#   → ~/.hermes/skills/，逐个技能判断目标是否存在
{ config, pkgs, lib, ... }:

{
  home.packages = [ (import ./package.nix { inherit pkgs lib; }) ];

  home.activation.hermes-seed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    hermes_dir="$HOME/.hermes"

    # ---- context：不存在才复制 ----
    if [ ! -e "$hermes_dir/SOUL.md" ]; then
      mkdir -p "$hermes_dir"
      cp "${../agent-context.md}" "$hermes_dir/SOUL.md"
      echo "hermes-seed: SOUL.md created from pi agent-context"
    fi

    # ---- skills：从 pi 的安装目录逐个复制，目标技能已存在则跳过 ----
    mkdir -p "$hermes_dir/skills"
    for src in "$HOME/.pi/agent/skills"/*; do
      [ -e "$src" ] || continue
      name="$(basename "$src")"
      if [ ! -e "$hermes_dir/skills/$name" ]; then
        cp -rL "$src" "$hermes_dir/skills/$name"
        echo "hermes-seed: skill '$name' copied from pi"
      fi
    done

    # ---- superpowers 技能（pi 经 git 包安装到 ~/.pi/agent/git/...）----
    superpowers="$HOME/.pi/agent/git/github.com/obra/superpowers/skills"
    if [ -d "$superpowers" ]; then
      for src in "$superpowers"/*; do
        [ -e "$src" ] || continue
        name="$(basename "$src")"
        if [ ! -e "$hermes_dir/skills/$name" ]; then
          cp -rL "$src" "$hermes_dir/skills/$name"
          echo "hermes-seed: skill '$name' copied from superpowers"
        fi
      done
    fi
  '';
}
