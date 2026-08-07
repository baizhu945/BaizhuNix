# hermes-agent 声明式安装 + context/skills 迁移
#
# 说明：
# - hermes 会自行修改 context（SOUL.md）与 skills（skill 管理/curator 等），
#   因此不能像 pi 那样用 home.file 符号链接（nix store 只读，hermes 无法写入），
#   而是用 activationScript 做真实拷贝；目标已存在则不复制（不比对内容），
#   保证 hermes 对文件的后续修改不会被 home-manager 覆盖。
# - context：agent-context.md → ~/.hermes/SOUL.md（SOUL.md 是 hermes 唯一从
#   HERMES_HOME 加载的全局 context 文件，每次会话注入）
# - skills：与 pi 的 skills.nix 同源（本地 agent/skills/ + anthropics/skills +
#   anbeime/skill + addyosmani/agent-skills + obra/superpowers），但直接在 nix
#   中 fetch 并固定 rev/sha256 —— 不依赖 pi agent 的运行时安装，任何没有 pi
#   的机器上用此配置都能独立构建出完整的技能集（可复现）。
#   注：pi 的 skills.nix 用的是 fetchGit ref="main"（未固定），此处全部固定。
{ config, pkgs, lib, ... }:

let
  # ---- 技能源（与 pi 的 skills.nix 同源，rev 固定）----
  # fetchSubmodules = false：anbeime/skill 的 .gitmodules 引用了不存在的
  # submodule（skills/NanoBanana-PPT-Skills），默认 true 会导致 fetch 失败；
  # 我们只需要主仓库里的技能目录，不需要 submodule
  anthropics-skills-repo = pkgs.fetchgit {
    url = "https://github.com/anthropics/skills.git";
    rev = "b29e7cf65e5cb78a5ac33d582270551bc74a14eb";
    sha256 = "1djisr7dk9g2dybfjnr6xwz4yil1ncbkjjrysvq4rqi3g39q2za4";
    fetchSubmodules = false;
  };

  anbeime-skills-repo = pkgs.fetchgit {
    url = "https://github.com/anbeime/skill.git";
    rev = "2f711d5054469e8d7694cd99495bdaab35331f27";
    sha256 = "07n8kl7vplkg19vvsp10rjsj8k6xj8gjgmr4z7cr4wlclbcav0w6";
    fetchSubmodules = false;
  };

  agent-skills-repo = pkgs.fetchgit {
    url = "https://github.com/addyosmani/agent-skills.git";
    rev = "d2478bf0c73a6357df39a3ed6aff16acaa218843";
    sha256 = "1rxvvfxc9iriljn8kyr9qdzr2cjyqjsaw9j74jnhbnf4vw1kmq4r";
    fetchSubmodules = false;
  };

  superpowers-repo = pkgs.fetchgit {
    url = "https://github.com/obra/superpowers.git";
    rev = "44c9b2d6e889982ac18c27d05a19fefe335194e1";
    sha256 = "0xsx1ns30l084j3wqlmsmd54jcdnbi9npz0ccvws1nnbncfpwyby";
    fetchSubmodules = false;
  };

  # 自包含的 seed 数据目录：context + 全部技能（真实文件，非符号链接）
  hermes-seed = pkgs.runCommand "hermes-seed" { } ''
    mkdir -p $out/skills

    # context
    cp ${../agent-context.md} $out/SOUL.md

    # 本地技能（agent/skills/）
    cp -r ${../skills}/* $out/skills/

    # anthropics/skills
    cp -r ${anthropics-skills-repo}/skills/docx          $out/skills/docx
    cp -r ${anthropics-skills-repo}/skills/pptx          $out/skills/pptx
    cp -r ${anthropics-skills-repo}/skills/xlsx          $out/skills/xlsx
    cp -r ${anthropics-skills-repo}/skills/pdf           $out/skills/pdf
    cp -r ${anthropics-skills-repo}/skills/canvas-design $out/skills/canvas-design

    # anbeime/skill
    cp -r ${anbeime-skills-repo}/skills/media-processor/media-processor $out/skills/media-processor

    # addyosmani/agent-skills
    cp -r ${agent-skills-repo}/skills/idea-refine $out/skills/idea-refine

    # obra/superpowers（pi 经 git 包安装的同源仓库）
    cp -r ${superpowers-repo}/skills/* $out/skills/
  '';
in
{
  home.packages = [ (import ./package.nix { inherit pkgs lib; }) ];

  home.activation.hermes-seed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    hermes_dir="$HOME/.hermes"
    seed="${hermes-seed}"

    # ---- context：不存在才复制 ----
    if [ ! -e "$hermes_dir/SOUL.md" ]; then
      mkdir -p "$hermes_dir"
      cp "$seed/SOUL.md" "$hermes_dir/SOUL.md"
      echo "hermes-seed: SOUL.md created from agent-context"
    fi

    # ---- skills：从 seed 逐个复制，目标技能已存在则跳过 ----
    mkdir -p "$hermes_dir/skills"
    for src in "$seed/skills"/*; do
      [ -e "$src" ] || continue
      name="$(basename "$src")"
      if [ ! -e "$hermes_dir/skills/$name" ]; then
        cp -r "$src" "$hermes_dir/skills/$name"
        echo "hermes-seed: skill '$name' copied"
      fi
    done
  '';
}
