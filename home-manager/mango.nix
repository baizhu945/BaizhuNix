{ config, pkgs, lib , ... }:

{
  home.packages = [
    (pkgs.writeShellScriptBin "mango-start" ''
      #!/bin/sh
      fcitx5 & nm-applet & blueman-applet & noctalia-shell & dms run
    '')

    (pkgs.writeShellScriptBin "focusmon_conditional" ''
      #!/usr/bin/env bash
      direction=$1
      monitors_info=$(mmsg -g -o)
      current_monitor=$(echo "$monitors_info" | awk '$3 == 1 {print $1}')
      all_monitors=($(echo "$monitors_info" | awk '{print $1}'))
      # 手动计算当前索引和数组长度
      current_index=-1
      len=''${#all_monitors[@]}
      for ((i=0; i<len; i++)); do
          if [[ "''${all_monitors[$i]}" == "$current_monitor" ]]; then
              current_index=$i
              break
          fi
      done
      case "$direction" in
          right|down)
              if (( current_index > 0 )); then
                  mmsg -d focusmon,"$direction"
              fi
              ;;
          left|up)
              if (( current_index < len - 1 )); then
                  mmsg -d focusmon,"$direction"
              fi
              ;;
      esac
    '')
  ];

  home.file = {
    ".config/mango/config.conf".text = ''
# ~/.config/mango/config.conf

env=LC_MESSAGES,zh_CN.UTF-8
env=XDG_CURRENT_DESKTOP,mango
env=XDG_SESSION_TYPE,wayland
env=GTK_IM_MODULE,fcitx
env=QT_IM_MODULE,fcitx
env=QT_IM_MODULES,wayland;fcitx
env=SDL_IM_MODULE,fcitx
env=XMODIFIERS,@im=fcitx
env=GLFW_IM_MODULE,ibus

monitorrule=model:F24B40Q,width:2560,height:1440,refresh:59.938,scale:1.6,x:0,y:0
monitorrule=model:MNG007DA5-3,width:2560,height:1600,refresh:165,scale:1.8,x:1600,y:0

exec-once=mango-start

numlockon=1
disable_while_typing=1
scroller_proportion_preset=0.33333,0.5,0.66667,0.99999
scroller_default_proportion = 0.66667
focus_on_activate=0
sloppyfocus=0
cursor_hide_timeout=3
drag_corner = 0
enable_hotarea = 0
exchange_cross_monitor = 0
trackpad_natural_scrolling = 1
accel_profile = 0

# 视觉特效与模糊
blur = 1
blur_layer=0
blur_optimized=1
blur_params_num_passes = 2
blur_params_radius = 5
blur_params_noise = 0.02
blur_params_brightness = 0.9
blur_params_contrast = 0.9
blur_params_saturation = 1.2
border_radius = 8
borderpx = 1
bordercolor = 0xb8b8b824
focuscolor = 0xe5e5e524
gappih = 9
gappoh = 3
shadows = 1
shadows_size = 10
shadows_blur = 15
shadows_position_x = 0
shadows_position_y = 0
shadowscolor = 0x00000070

# 通用布局设置
tagrule=id:1,layout_name:scroller
tagrule=id:2,layout_name:scroller
tagrule=id:3,layout_name:scroller
tagrule=id:4,layout_name:scroller
tagrule=id:5,layout_name:scroller
tagrule=id:6,layout_name:scroller
tagrule=id:7,layout_name:scroller
tagrule=id:8,layout_name:scroller
tagrule=id:9,layout_name:scroller

# 窗口规则 (符合 MangoWC 语法)
# 1. 全局基础规则 (所有窗口)
# 圆角 8px，略微透明以显示模糊背景
border_radius=8
focused_opacity=1
unfocused_opacity=1

# 2. 终端窗口规则 (Alacritty, Kitty, Ghostty)
# 根据焦点状态设置不同的透明度
windowrule=focused_opacity:0.85,scroller_proportion:0.5,appid:^Alacritty$
windowrule=focused_opacity:0.85,scroller_proportion:0.5,appid:^kitty$
windowrule=focused_opacity:0.85,scroller_proportion:0.5,appid:^com\.mitchellh\.ghostty$

windowrule=unfocused_opacity:0.82,scroller_proportion:0.5,appid:^Alacritty$
windowrule=unfocused_opacity:0.82,scroller_proportion:0.5,appid:^kitty$
windowrule=unfocused_opacity:0.82,scroller_proportion:0.5,appid:^com\.mitchellh\.ghostty$

# 3. 浮动窗口规则 (画中画窗口)
windowrule=isfloating:1,appid:^firefox$,title:^Picture-in-Picture$
windowrule=isfloating:1,appid:^google-chrome$,title:^Picture-in-Picture$
windowrule=isfloating:1,appid:^one\.alynx\.showmethekey$,title:^Floating Window - Show Me The Key$

# 4. 通用浮动窗口位置规则 (位于右上角)
# offsetx/offsety 相对于屏幕中心，20 和 -30 会使窗口出现在右上区域
windowrule=offsetx:20,offsety:30,isfloating:1,appid:^$,title:^$

windowrule = noblur:1,appid:slurp

#
# 快捷键
# 注：MangoWC 中的 "Tag" 概念对应 Niri 的 "Workspace"

# 热键帮助 (原 Niri 的 show-hotkey-overlay)
bind = SUPER+Shift,Slash, spawn_shell, noctalia-shell ipc call plugin:keybind-cheatsheet toggle

# 应用启动器
bind = SUPER,T, spawn, ghostty
bind = SUPER+Shift,T, spawn, alacritty
bind = SUPER,D, spawn_shell, noctalia-shell ipc call launcher toggle
bind = SUPER,B, spawn, firefox
bind = SUPER,E, spawn_shell, noctalia-shell ipc call launcher emoji
bind = SUPER+Shift,B, spawn, google-chrome-stable
bind = SUPER,F, spawn, dolphin
bind = SUPER,C, spawn, qalculate-gtk
bind = SUPER,Z, spawn_shell, noctalia-shell ipc call launcher clipboard
bind = SUPER+Alt,B, spawn, brave

# 面板/小组件切换
bind = SUPER,H, spawn_shell, noctalia-shell ipc call bar toggle
bind = SUPER+Alt,H, spawn_shell, noctalia-shell ipc call plugin:show-keys toggle
bind = SUPER+Shift,H, spawn_shell, noctalia-shell ipc call desktopWidgets toggle
bind = SUPER,L, spawn_shell, lyrics-toggle

# 打开 Open-WebUI
bind = SUPER,A, spawn_shell, firefox http://127.0.0.1:8080/

# 涂鸦功能
bind = SUPER+Ctrl,W, spawn_shell, chameleos --stroke-width 4 & noctalia-shell ipc call toast send '{"title":"进入涂鸦模式"}' & sleep 0.1 && chamel toggle
bind = SUPER+Shift,W, spawn_shell, noctalia-shell ipc call plugin:screen-toolkit annotate
bind = SUPER+Ctrl,E, spawn_shell, chamel exit && noctalia-shell ipc call toast send '{"title":"退出涂鸦模式"}'
bind = SUPER+Ctrl,Z, spawn_shell, chamel undo
bind = SUPER+Ctrl,C, spawn_shell, chamel clear

# 媒体键 (音量/播放)
# bind = XF86AudioRaiseVolume, spawn_shell, wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+ -l 1.0
# bind = XF86AudioLowerVolume, spawn_shell, wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-
# bind = XF86AudioMute, spawn_shell, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
# bind = XF86AudioMicMute, spawn_shell, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
# bind = XF86AudioPlay, spawn_shell, noctalia-shell ipc call media play
# bind = XF86AudioStop, spawn_shell, noctalia-shell ipc call media stop
# bind = XF86AudioPrev, spawn_shell, noctalia-shell ipc call media previous
# bind = XF86AudioNext, spawn_shell, noctalia-shell ipc call media next

# 亮度
# bind = XF86MonBrightnessUp, spawn_shell, noctalia-shell ipc call brightness increase
# bind = XF86MonBrightnessDown, spawn_shell, noctalia-shell ipc call brightness decrease

# 窗口管理基础
bind = SUPER,O, toggleoverview
bind = SUPER,Q, killclient

# 焦点移动 (列/窗口方向)
bind = SUPER,Left, focusdir, left
bind = SUPER,Down, focusdir, down
bind = SUPER,Up, focusdir, up
bind = SUPER,Right, focusdir, right

# 窗口移动 (列/窗口方向)
bind = SUPER+Ctrl,Left, exchange_client, left
bind = SUPER+Ctrl,Down, exchange_client, down
bind = SUPER+Ctrl,Up, exchange_client, up
bind = SUPER+Ctrl,Right, exchange_client, right

# 焦点到列的首/尾
bind = SUPER,Home, focusstack, first
bind = SUPER,End, focusstack, last

# 移动列到首/尾
bind = SUPER+Ctrl,Home, exchange_client, first
bind = SUPER+Ctrl,End, exchange_client, last

# 多显示器焦点
# bind = SUPER+Shift,Left, focusmon, left
# bind = SUPER+Shift,Down, focusmon, down
# bind = SUPER+Shift,Up, focusmon, up
# bind = SUPER+Shift,Right, focusmon, right

bind = SUPER+Shift,Left, spawn_shell, focusmon_conditional left
bind = SUPER+Shift,Down, spawn_shell, focusmon_conditional down
bind = SUPER+Shift,Up, spawn_shell, focusmon_conditional up
bind = SUPER+Shift,Right, spawn_shell, focusmon_conditional right

# 移动列到其他显示器
bind = SUPER+Shift+Ctrl,Left, tagmon, left
bind = SUPER+Shift+Ctrl,Down, tagmon, down
bind = SUPER+Shift+Ctrl,Up, tagmon, up
bind = SUPER+Shift+Ctrl,Right, tagmon, right

# 标签 (Tag) 管理 (对应 Niri 工作区)
bind = SUPER,Page_Down, view, downtag
bind = SUPER,Page_Up, view, uptag
bind = SUPER+Ctrl,Page_Down, tag, down
bind = SUPER+Ctrl,Page_Up, tag, up

# 切换到指定标签 (1-9)
bind = SUPER,1, view, 1
bind = SUPER,2, view, 2
bind = SUPER,3, view, 3
bind = SUPER,4, view, 4
bind = SUPER,5, view, 5
bind = SUPER,6, view, 6
bind = SUPER,7, view, 7
bind = SUPER,8, view, 8
bind = SUPER,9, view, 9

# 移动窗口到指定标签
bind = SUPER+Ctrl,1, tag, 1
bind = SUPER+Ctrl,2, tag, 2
bind = SUPER+Ctrl,3, tag, 3
bind = SUPER+Ctrl,4, tag, 4
bind = SUPER+Ctrl,5, tag, 5
bind = SUPER+Ctrl,6, tag, 6
bind = SUPER+Ctrl,7, tag, 7
bind = SUPER+Ctrl,8, tag, 8
bind = SUPER+Ctrl,9, tag, 9

# 调整列宽 (按比例)
bind = SUPER,R,switch_proportion_preset
bind = SUPER,Minus, setmfact, -0.05
bind = SUPER,Equal, setmfact, +0.05

# 浮动模式切换
bind = SUPER,V, togglefloating
bind = SUPER+Shift,V, togglefloating

# 截图
bind = SUPER+Shift,P, spawn_shell, grim -l 0 -g "$(slurp)" -c /home/baizhu945/Pictures/Screenshots/$(date +'%s_grim.png') && wl-copy < ~/Pictures/Screenshots/$(date +'%s_grim.png') && noctalia-shell ipc call toast send '{"title":"区域截图"}'
bind = SUPER+Ctrl,P, spawn_shell, grim -l 0 -c $(xdg-user-dir PICTURES)/Screenshots/$(date +'%s_grim.png') && wl-copy < ~/Pictures/Screenshots/$(date +'%s_grim.png') && noctalia-shell ipc call toast send '{"title":"屏幕截图"}'
bind = SUPER+Alt,P, spawn_shell, noctalia-shell ipc call plugin:screen-toolkit pin

# 禁止快捷键 / 退出
bind = SUPER+Shift,E, reload_config
bind = CTRL+Alt,Delete, quit
    '';
  };
}
