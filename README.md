**该仓库是nixos-unstable的配置，且是一个去flake的配置，主要用于给自己备份。但是对于qemu/KVM虚拟机包含了一些补丁，有需要的可以借用**

# 一、安装home-manager
```
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager

nix-channel --update

nix-shell '<home-manager>' -A install
```

# 二、改nix-unstable（如果最初安装的是稳定版而不是unstable版）
```
sudo nix-channel --remove nixos

sudo nix-channel --add https://channels.nixos.org/nixos-unstable nixos

sudo nix-channel --update
```

# 三、添加nixpkgs
```
nix-channel --add https://nixos.org/channels/nixpkgs-unstable

nix-channel --update
```

# 四、创建virt-manager默认网络
```
sudo virsh net-define /var/lib/libvirt/qemu/networks/default.xml

sudo virsh net-create /var/lib/libvirt/qemu/networks/default.xml

sudo virsh net-autostart default
```

# 五、noctalia插件列表无法刷新
```
git clone https://github.com/noctalia-dev/noctalia-plugins

node noctalia-plugins/registry.json
```

# 六、onlyoffice不识别系统安装的中文字体
`/nix/store`后面的哈希值路径会随着版本变化，需要在自己的系统中查找，与下面的不一定一样
```
mkdir -p ~/.local/share/fonts

sudo cp /nix/store/lq0h9dp1capyrlgis2gz5qxsvw211244-corefonts-1/share/fonts/truetype/* ~/.local/share/fonts/

sudo cp /nix/store/8rxvh1p7jpjxkv23jj246j7xm0ff6ps0-vista-fonts-1/share/fonts/truetype/* ~/.local/share/fonts/

sudo cp /nix/store/ii65s09vhczsslbdbdikfibfh6bnnf6s-vista-fonts-chs-1/share/fonts/truetype/* ~/.local/share/fonts/

sudo cp /nix/store/m67c7fna8xjvf6qq8l0g4hn4y7smr6qc-vista-fonts-cht-1/share/fonts/truetype/* ~/.local/share/fonts/

sudo fc-cache -fv
```
若还有windows系统，则可以复制windows系统的字体到`~/.local/share/fonts/`中，然后运行`rm ~/.local/share/fonts/*.fon`

# 七、使用conda安装一些工具

## 在conda中安装`pix2tex`
```
conda-shell # 进入conda环境

conda create -n latexocr # 创建环境
```
然后按照 https://github.com/lukas-blecher/LaTeX-OCR 进行安装

## 在conda中安装`melo tts`
```
conda create -n tts python=3.9
```

根据 https://pytorch.org/get-started/locally/ 安装pytorch

根据 https://github.com/myshell-ai/MeloTTS 安装melo tts，其中`git clone`步骤最好先`cd ~/.conda/envs/tts`后再运行，为了保持`home`目录整洁。

运行`python -m unidic download`后，执行
```
python #进入python环境

import nltk

nltk.download()
```

选择all，下载全部模型

将`nltk_data`文件夹移动到`~/.conda/envs/tts/share/`中

分别运行下面两个命令，进行初始化操作
```
melo "Hello world 测试一下中英混读" out.wav

melo "Hello world 测试一下中英混读" out.wav --language ZH
```

# 八、noctalia配置
## 插件
`Catwalk`、`KDE Connect`、`Keybind Cheatsheet`、`SuperGFX Control`、`Screen Recorder`、`Screen Toolkit`、`Todo List`
## CustomButton
### 启动器
Left click: `noctalia-shell ipc call launcher toggle`

### Wallpaper
Left click: `noctalia-shell ipc call wallpaper random eDP-2 & noctalia-shell ipc call wallpaper random eDP-1 & noctalia-shell ipc call wallpaper random HDMI-A-1`

Right click: `noctalia-shell ipc call wallpaper toggle`

### 截图
Left click: `grim -l 0 -g "$(slurp)" -c /home/baizhu945/Pictures/Screenshots/$(date +'%s_grim.png') && wl-copy < ~/Pictures/Screenshots/$(date +'%s_grim.png') && noctalia-shell ipc call toast send '{"title":"区域截图"}'`

Right click: `grim -l 0 -c $(xdg-user-dir PICTURES)/Screenshots/$(date +'%s_grim.png') && wl-copy < ~/Pictures/Screenshots/$(date +'%s_grim.png') && noctalia-shell ipc call toast send '{"title":"屏幕截图"}'`

### 朗读
Left click: `speak_from_clipboard-zh`

Right click: `speak_from_clipboard-en`

### Clean nix cache
Left click: `noctalia-shell ipc call toast send '{"title":"Cleaning"}' && echo <yourpasswd> | sudo -S nh clean all && noctalia-shell ipc call toast send '{"title":"Clean Completed"}'`

### Show lyrics
显示命令输出: `waybar-lyrics`

流: `ON`

将输出解析为JSON: `ON`

### Show Open-WebUI avalibility
左键单击: `firefox http://127.0.0.1:8080/`

显示命令输出: `curl -sf http://127.0.0.1:8080/api/version \ | jq -e '.version and (.version | length > 0)'`

流: `ON`

最大文本长度: `0`

# 九、DankMaterialShell配置
放在底部且自动隐藏，将其当作一个dock栏使用
## 插件
`Asus Control Centor`、`Display Mirror`、`Display Manager`、`Display Settings`、`Power Usage Monitor`、`Music Lyrics`

# 十、Dual boot trouble shooting
## Windows 时间错乱
参考 https://wiki.archlinux.org/title/System_time#UTC_in_Microsoft_Windows

## 每次从 Windows 关机后， BIOS 启动顺序被万恶的微软篡改
使用 `efibootmgr` 获取 Windows 启动的编号，然后运行
```
sudo efibootmgr -b 0002 --inactive # 把 0002 更换为 Windows 的编号
```

# 十一、Known BUGs
## Screen Recording
在`niri`中，`noctalia`的屏幕录像可用，`obs`的`Wayland output(dmabuf)`不可用，`Wayland output(scpy)`可用但是画面泛黄

在`mangowc`中，`noctalia`的屏幕录像不可用，`obs`的`Wayland output(dmabuf)`可用，`Wayland output(scpy)`不可用

## `ventoy` & `gparted`
在`mangowc`中，`ventoy`和`gparted`无法启动，但是在其他桌面能够正常启动
