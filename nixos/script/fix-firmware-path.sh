#!/usr/bin/env bash
# 修复 libvirt VM 固件路径，使用稳定的 NixOS 符号链接

# ── 确保 /var/lib/libvirt/qemu.conf 里有 nvram 配对配置 ─────────────────
if ! grep -q "nix-ovmf" /var/lib/libvirt/qemu.conf 2>/dev/null; then
  cat >> /var/lib/libvirt/qemu.conf << 'QEMUCONF'

nvram = [
  "/run/libvirt/nix-ovmf/edk2-x86_64-code.fd:/run/libvirt/nix-ovmf/edk2-i386-vars.fd",
  "/run/libvirt/nix-ovmf/edk2-x86_64-secure-code.fd:/run/libvirt/nix-ovmf/edk2-i386-vars.fd"
]
QEMUCONF
  echo "Appended nvram config to qemu.conf"
fi

# ── 修复所有虚拟机 XML 文件 ──────────────────────────────────────────────
if [ -d /var/lib/libvirt/qemu ]; then
  for xmlfile in /var/lib/libvirt/qemu/*.xml; do
    [ -f "$xmlfile" ] || continue

    # 修复 <emulator> 标签：把任意版本的 store 路径替换成稳定 symlink 路径
    sed -i \
      's|/nix/store/[^/]*/bin/\(qemu-[^<]*\)|/run/libvirt/nix-emulators/\1|g' \
      "$xmlfile"

    # 修复 <loader> 的 secure-code 路径（先匹配更具体的）
    sed -i \
      's|/nix/store/[^<]*edk2-x86_64-secure-code\.fd|/run/libvirt/nix-ovmf/edk2-x86_64-secure-code.fd|g' \
      "$xmlfile"

    # 修复 <loader> 的普通 UEFI code 路径
    sed -i \
      's|/nix/store/[^<]*edk2-x86_64-code\.fd|/run/libvirt/nix-ovmf/edk2-x86_64-code.fd|g' \
      "$xmlfile"

    # 修复 <nvram> template 属性——单引号版本
    sed -i \
      "s|template='/nix/store/[^']*edk2-i386-vars\.fd'|template='/run/libvirt/nix-ovmf/edk2-i386-vars.fd'|g" \
      "$xmlfile"

    # 修复 <nvram> template 属性——双引号版本
    sed -i \
      's|template="/nix/store/[^"]*edk2-i386-vars\.fd"|template="/run/libvirt/nix-ovmf/edk2-i386-vars.fd"|g' \
      "$xmlfile"

    echo "Fixed: $xmlfile"
  done
fi
