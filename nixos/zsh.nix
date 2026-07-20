{ config, pkgs, lib, ... }:

let
  realRm = "${pkgs.coreutils}/bin/rm";
in
{
  programs.zsh = {
    enable = true;
    enableCompletion = false;
    enableBashCompletion = false;
    autosuggestions = {
      enable = true;
      strategy = [ "history" "completion" ];
    };
    syntaxHighlighting.enable = true;
    histSize = 20000;
    shellAliases = {
      ls = "lsd";
      sudo = "sudo ";
    };
    ohMyZsh = {
      enable = true;
      theme = "re5et";
      plugins = [
        "command-not-found"
        "colored-man-pages"
        "fancy-ctrl-z"
      ];
    };
    interactiveShellInit = ''
      autoload -Uz add-zsh-hook
      ZSH_COMPDUMP="$HOME/.cache/zsh/compdump-$HOST"
      mkdir -p "''${ZSH_COMPDUMP:h}"
      rm() { ${realRm} "$@"; }
      _opencode_restore_rm() {
        unfunction rm 2>/dev/null
        add-zsh-hook -d precmd _opencode_restore_rm
      }
      add-zsh-hook precmd _opencode_restore_rm
      autoload -U compinit && compinit
      autoload -U bashcompinit && bashcompinit
    '';
    promptInit = ''
      # PROMPT：FAIL 后带两个换行
      PROMPT='%(?,,)%F{109}%n%{$reset_color%}@%F{195}%m%{$reset_color%}: %{$fg_bold[blue]%}%~%}
    >%(prompt_char) '
      autoload -Uz add-zsh-hook
      _newline_between_prompts() {
        # 如果上一条命令失败（exit code ≠ 0），不要额外加空行
        if [[ $? -ne 0 ]]; then
          return
        fi
        # 正常情况下插入空行（但跳过第一次）
        $funcstack[1]() echo
      }
      add-zsh-hook precmd _newline_between_prompts
    '';
  };

  programs.command-not-found.enable = true; # Needed by "command-not-found" plugin

  users.users.<yourusername>.shell = pkgs.zsh;
}
