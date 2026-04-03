{ config, pkgs, lib, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    enableBashCompletion = true;
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

  programs.zsh.ohMyZsh = {
    enable = true;
    theme = "re5et";
    plugins = [
      "colorize"
      "command-not-found"
      "colored-man-pages"
      "fancy-ctrl-z"
    ];
  };

  users.users.baizhu945.shell = pkgs.zsh;
}
