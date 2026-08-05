{ config, pkgs, lib, ... }:

{
  # 用 nixpkgs overlay 给 pi 打补丁：底部消费金额以人民币（¥）显示，而非美元（$）
  # 补丁见 cost-cny.patch；汇率由 currency-rate.ts 扩展实时抓取写入 PI_USD_CNY_RATE
  # （扩展不可用时回退到固定值 7.2）
  nixpkgs.overlays = [
    (final: prev: {
      pi-coding-agent = prev.pi-coding-agent.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./patches/cost-cny.patch ./patches/sidebar-layout.patch ];
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

      retry.enabled = true;
      retry.maxRetries = 5;

      # pi 包：ask_user 工具（@d3ara1n/pi-ask-user）
      # 有多个方案需要用户决策时，在底部编辑器槽位渲染可折叠面板列出选项（单/多选、可自定义输入），
      # 不遮住上方的对话记录。版本已固定；pi 启动时若 ~/.pi/agent/npm/ 下未安装会自动安装。
      # pi 包：pi-web-access（web_search / fetch_content / get_search_content / source_check）
      # Web 搜索 + URL 抓取 + GitHub 克隆 + PDF 提取 + 视频理解；零配置（Exa 兜底），
      # 可选在 ~/.pi/web-search.json 配 API key；ffmpeg/yt-dlp 仅视频抽帧时可选需要。
      packages = [
        "npm:@d3ara1n/pi-ask-user@2.4.2"
        "npm:pi-web-access@0.18.0"
      ];
    };
  };

  # skills：pi 的全局技能根是 ~/.pi/agent/skills/，逐个软链（reasonix.nix 同款做法）
  # 权限 gate：~/.pi/agent/extensions/ 下的 .ts 会被 pi 自动发现并加载
  home.file = {
    # pi-web-access 配置：本机 Clash/Mihomo TUN 代理把公网域名解析成 198.18.0.0/15
    # 的 fake-IP，导致包内 SSRF DNS 预检拦截所有抓取。仅放行该代理合成网段
    # （私网/localhost/字面 IP 仍被拦截，安全语义不变）。
    ".pi/web-search.json".text = ''
      {
        "ssrf": {
          "allowRanges": ["198.18.0.0/15"]
        }
      }
    '';

    ".pi/agent/extensions/" = {
      source = ./extensions;
      recursive = true;
    };

    ".pi/agent/agents/" = {
      source = ./agents;
      recursive = true;
    };

    # ---- 快捷键：思维链折叠/展开（alt+t 为未占用的新键，ctrl+t 为内置默认）----
    ".pi/agent/keybindings.json".source = ./keybindings.json;
  };
}
