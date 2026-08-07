#!/usr/bin/env bash
# git-update:备份本地配置到 BaizhuNix 仓库(含子模块正确处理)
cd ~/Documents/BaizhuNix

# 收集 .gitmodules 中登记的子模块路径(相对仓库根)
SUBMODULES=$(git config --file .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null | cut -d' ' -f2 || true)

remove-without-permission -r nixos
remove-without-permission n\&d.7z

# 同步 home-manager(排除子模块目录;--delete 保证本地已删除的文件不残留)
rsync_args=(-a --delete)
for sm in $SUBMODULES; do
    rel="${sm#home-manager/}"
    [ "$rel" != "$sm" ] && rsync_args+=(--exclude "$rel")
done
rsync "${rsync_args[@]}" ~/.config/home-manager/ ~/Documents/BaizhuNix/home-manager/

cp -r ~/.config/noctalia/ ~/Documents/BaizhuNix/
cp -r ~/.config/DankMaterialShell/ ~/Documents/BaizhuNix/
cp -r /etc/nixos/ ~/Documents/BaizhuNix/

# 若子模块是嵌入式仓库(.git 目录),先转为标准子模块布局(.git/modules)
git submodule absorbgitdirs 2>/dev/null || true

# 重建/更新子模块工作区,HEAD 跟随本地 clone,内容与本地一致
for sm in $SUBMODULES; do
    [ -n "$sm" ] || continue
    git submodule update --init --recursive "$sm" >/dev/null 2>&1 || true
    local_src="$HOME/.config/$sm"
    if [ -f "$sm/.git" ] && [ -d "$local_src" ]; then
        # 内容覆盖为本地工作区(排除 .git)
        rsync -a --delete --exclude='.git' "$local_src/" "$sm/"
        # HEAD 跟随本地 clone(对象缺失时先从本地拉取)
        local_head=$(git -C "$local_src" rev-parse HEAD 2>/dev/null || true)
        if [ -n "$local_head" ]; then
            git -C "$sm" cat-file -e "$local_head" 2>/dev/null || git -C "$sm" fetch "$local_src" "$local_head" >/dev/null 2>&1 || true
            git -C "$sm" update-ref HEAD "$local_head" 2>/dev/null || true
        fi
    fi
done

shopt -s nullglob
for dir in DankMaterialShell/plugins/*; do
    [ -d "$dir" ] || continue
    remove-without-permission -rf "$dir/.git"
    git rm -r --cached --ignore-unmatch "$dir"
done

# sed 脱敏时排除子模块目录(子模块内容由各自仓库管理,不应被改动)
sed_prune=()
for sm in $SUBMODULES; do
    [ -n "$sm" ] || continue
    sed_prune+=(-path "./$sm" -prune -o)
done

find . -path "./README.md" -prune -o -path "./.git" -prune -o -path "./.gitmodules" -prune -o "${sed_prune[@]}" -type f -name "*" -exec sed -i 's/<yourusername>/<yourusername>/g' {} +
find . -path "./README.md" -prune -o -path "./.git" -prune -o -path "./.gitmodules" -prune -o "${sed_prune[@]}" -type f -name "*" -exec sed -i 's/<yourpassword>/<yourpassword>/g' {} +

7z a -o{~/Documents/BaizhuNix} n\&d.7z noctalia/ DankMaterialShell

remove-without-permission -r noctalia/
remove-without-permission -r  DankMaterialShell/

git status
