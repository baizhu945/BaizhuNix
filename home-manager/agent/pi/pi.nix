{ config, pkgs, lib, ... }:

{
  # 用 nixpkgs overlay 给 pi 打补丁：底部消费金额以人民币（¥）显示，而非美元（$）
  # 补丁见 cost-cny.patch；汇率由 currency-rate.ts 扩展实时抓取写入 PI_USD_CNY_RATE
  # （扩展不可用时回退到固定值 7.2）
  nixpkgs.overlays = [
    (final: prev: {
      pi-coding-agent = prev.pi-coding-agent.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./cost-cny.patch ];
      });
    })
  ];

  imports = [
    ./skills.nix
    ../cc-connect.nix
  ];

  programs.pi-coding-agent = {
    enable = true;

    # 让技能脚本可用的 nodejs（与 opencode.nix 的 extraPackages 一致）
    extraPackages = with pkgs; [ nodejs ];

    # 全局 context：与 opencode.nix 使用同一个 agent-context.md
    # 模块会将其写入 ~/.pi/agent/AGENTS.md
    context = ../agent-context.md;

    settings = {
      # 项目级资源（.pi/settings.json、项目 skills 等）默认询问是否信任
      defaultProjectTrust = "ask";

      # 默认模型：DeepSeek V4 Flash
      # （defaultProvider 必须与 defaultModel 一起设置，模型解析器两者都需要）
      defaultProvider = "deepseek";
      defaultModel = "deepseek-v4-flash";

      # 思维链默认展开（false = 不隐藏 thinking 块）；ctrl+t / alt+t 可随时折叠/展开
      hideThinkingBlock = false;
    };
  };

  # skills：pi 的全局技能根是 ~/.pi/agent/skills/，逐个软链（reasonix.nix 同款做法）
  # 权限 gate：~/.pi/agent/extensions/ 下的 .ts 会被 pi 自动发现并加载
  home.file = {
    # ---- 权限 gate：只读放行，写/执行询问用户 ----
    ".pi/agent/extensions/permission-gate.ts".source = ./extensions/permission-gate.ts;

    # ---- subagent 扩展：在独立 pi 进程中运行子代理（官方示例移植，支持 general/explore）----
    # ---- todo 工具：结构化任务列表（官方示例持久化 + OpenCode 四态语义）----
    ".pi/agent/extensions/todo.ts".source = ./extensions/todo.ts;

    # ---- 实时汇率扩展：为打补丁的 footer 提供实时 USD→CNY 汇率 ----
    ".pi/agent/extensions/currency-rate.ts".source = ./extensions/currency-rate.ts;

    # agents 定义在 ~/.pi/agent/agents/ 下（见下方），工具描述已在 index.ts 中改写为中文说明
    ".pi/agent/extensions/subagent/index.ts".source = ./extensions/subagent/index.ts;
    ".pi/agent/extensions/subagent/agents.ts".source = ./extensions/subagent/agents.ts;



    # ---- subagent agents：OpenCode general/explore subagent 的 Pi 移植 ----
    ".pi/agent/agents/general.md".source = ./agents/general.md;
    ".pi/agent/agents/explore.md".source = ./agents/explore.md;

    # ---- 快捷键：思维链折叠/展开（alt+t 为未占用的新键，ctrl+t 为内置默认）----
    ".pi/agent/keybindings.json".source = ./keybindings.json;

  };
}
