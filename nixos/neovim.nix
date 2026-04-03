{ config, pkgs, lib,  ... }:

let
  nixvim = import (builtins.fetchGit {
    url = "https://github.com/nix-community/nixvim";
  });
in
{
  imports = [ nixvim.nixosModules.nixvim ];

  security.sudo.extraConfig = ''
    # 保留 Wayland 和 X11 的显示及认证变量，解决剪贴板和显示问题
    Defaults env_keep += "WAYLAND_DISPLAY XAUTHORITY DISPLAY XDG_RUNTIME_DIR"
  '';

  programs.nixvim = {
    enable = true;
    vimAlias = true;
    viAlias = true;
    defaultEditor = true;
    colorschemes.cyberdream = {
      enable = true;
      luaConfig.post = ''
        -- 将所有覆盖逻辑放进 ColorScheme autocmd，
        -- 确保它永远在主题完全应用之后才执行，不会被覆盖
        vim.api.nvim_create_autocmd("ColorScheme", {
          pattern = "*",
          callback = function()
    
            -- ── 背景透明 ──────────────────────────────────────────
            -- 让终端/WM 的背景透过来
            vim.api.nvim_set_hl(0, "Normal",      { bg = "none" })
            vim.api.nvim_set_hl(0, "NormalNC",    { bg = "none" })
            vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
            vim.api.nvim_set_hl(0, "FloatBorder", { bg = "none" })
            vim.api.nvim_set_hl(0, "SignColumn",  { bg = "none" })
    
            -- ── 恢复折叠行的视觉区分 ──────────────────────────────
            -- cyberdream 把 Folded 的 bg 设得和 Normal 一样，
            vim.api.nvim_set_hl(0, "Folded", {
              bg = "#1e2030",   -- 比 Normal 深的颜色，根据你的终端背景调整
              fg = "#636da6",   -- 折叠行的文字颜色（偏蓝灰）
              italic = true,
            })
    
            -- ── 恢复状态栏的视觉区分 ──────────────────────────────
            vim.api.nvim_set_hl(0, "StatusLine",   { bg = "#1a1b2e", fg = "#c8d3f5" })
            vim.api.nvim_set_hl(0, "StatusLineNC", { bg = "#16161e", fg = "#545c7e" })
          end,
        })
      '';
    };
  
    extraPackages = with pkgs; [ 
      ripgrep
      fd
      # 拦截并重写 tree-sitter 包，强行拉取 0.26.7 版本
      (tree-sitter.overrideAttrs (old: rec {
        version = "0.26.7";
        src = fetchFromGitHub {
          owner = "tree-sitter";
          repo = "tree-sitter";
          rev = "v${version}";
          hash = "sha256-O3c2djKhM+vIYunthDApi9sw/gFH/FBME1uR4N+9MFM="; 
        };
      	nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ 
          llvmPackages.libclang 
          rustPlatform.bindgenHook 
        ];
        LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";
      	patches = [];
  	    doCheck = false;
  	    cargoDeps = rustPlatform.importCargoLock {
	        lockFile = "${src}/Cargo.lock";
	      };
      }))
    ];
  
    opts = {
      number = true;
      guicursor = "";

      # Needed by ufo
      foldcolumn = "0";
      foldlevel = 99;
      foldlevelstart = 99;
      foldenable = true;

      # 修复缩进
      smartindent = false; # Treesitter 开启时，smartindent 有时会起反作用
      expandtab = true;    # 使用空格替代制表符（推荐）
      shiftwidth = 2;      # Nix 建议缩进为 2
      tabstop = 2;
    };
  
    extraConfigLua = ''
      -- Comment.nvim 清理
      vim.keymap.del('n', 'gc')
      vim.keymap.del('x', 'gc')

      -- 自动保存和加载视图（包含折叠信息）
      vim.api.nvim_create_autocmd({ "BufWinLeave" }, {
        pattern = { "*.*" },
        callback = function()
          -- 排除一些不需要记录视图的缓冲区（如 NvimTree, 插件面板等）
          if vim.bo.buftype == "" then
            vim.cmd("silent! mkview")
          end
        end,
      })
      vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
        pattern = { "*.*" },
        callback = function()
          if vim.bo.buftype == "" then
            vim.cmd("silent! loadview")
          end
        end,
      })
    '';
  
    extraPlugins = with pkgs.vimPlugins; [
      coc-nvim
      promise-async
    ];
  
    plugins = {
      nvim-treesitter = {
        enable = true;
        grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [ nix ];
      };
      # Needed by ufo to fold nix
      treesitter = {
        enable = true;
      	settings = {
          highlight.enable = true;
	        indent.enable = true;
      	};
      };
  
      nvim-ufo = {
        enable = true;
        settings = {
          # nix 文件禁用 ufo 内部 provider，让原生 treesitter foldexpr 接管
          provider_selector = ''
            function(bufnr, filetype, buftype)
              return { 'treesitter', 'indent' }
            end
          '';
  
          fold_virt_text_handler = ''
            function(virtText, lnum, endLnum, width, truncate)
                local newVirtText = {}
                local suffix = (' 󰁂 󰁂 󰁂  %d '):format(endLnum - lnum)
                local sufWidth = vim.fn.strdisplaywidth(suffix)
                local targetWidth = width - sufWidth
                local curWidth = 0
                for _, chunk in ipairs(virtText) do
                    local chunkText = chunk[1]
                    local chunkWidth = vim.fn.strdisplaywidth(chunkText)
                    if targetWidth > curWidth + chunkWidth then
                        table.insert(newVirtText, chunk)
                    else
                        chunkText = truncate(chunkText, targetWidth - curWidth)
                        local hlGroup = chunk[2]
                        table.insert(newVirtText, {chunkText, hlGroup})
                        chunkWidth = vim.fn.strdisplaywidth(chunkText)
                        if curWidth + chunkWidth < targetWidth then
                            suffix = suffix .. (' '):rep(targetWidth - curWidth - chunkWidth)
                        end
                        break
                    end
                    curWidth = curWidth + chunkWidth
                end
                table.insert(newVirtText, {suffix, 'MoreMsg'})
                return newVirtText
            end
          '';
        };
      };
  
      image.enable = true;
      flash.enable = true;
      markdown-preview.enable = true;
      telescope.enable = true;
      web-devicons.enable = true;
      Comment.enable = true;
      which-key.enable = true;
      mini.enable = true;
      neo-tree = {
        enable = true;
        settings = {
          filesystem = {
            follow_current_file = {
              enabled = true;
              leaveDirsOpen = false;
            };
            filtered_items = {
              visible = true;
              showHidden = true;
              showGitignored = false;
            };
          };
        };
      };
    };
  };
}
